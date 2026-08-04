package mobileNebula

import (
	"crypto/rand"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net"
	"net/netip"
	"strings"
	"time"

	"github.com/slackhq/nebula"
	"github.com/slackhq/nebula/cert"
	nc "github.com/slackhq/nebula/config"
	"github.com/slackhq/nebula/util"
	"golang.org/x/crypto/curve25519"
	"gopkg.in/yaml.v2"
)

type m map[string]any

type CIDR struct {
	IPLen         int    // The number of bytes in the address family, 4 for ipv4, 16 for ipv6
	Address       string // Apple and Android wants the string of the ip address
	MaskedAddress string // Apple wants the address masked by SubnetMask for routes
	SubnetMask    string // Apple wants the old style subnet mask for ipv4 (255.255.255.0), this will be empty for ipv6 CIDRs
	PrefixLength  int    // Apple wants the prefix length from the cidr notation when dealing with ipv6 and Android always wants it
}

type Validity struct {
	Valid  bool
	Reason string
}

type RawCert struct {
	RawCert  string
	Cert     m
	Validity Validity
}

type KeyPair struct {
	PublicKey  string
	PrivateKey string
}

// RenderConfig takes a new-format site JSON (with rawConfig) and a private key,
// and returns the full nebula YAML config with the key injected.
func RenderConfig(configData string, key string) (string, error) {
	var d map[string]interface{}

	err := json.Unmarshal([]byte(configData), &d)
	if err != nil {
		return "", err
	}

	rawConfigStr, ok := d["rawConfig"].(string)
	if !ok {
		// Try legacy format for backwards compatibility
		return renderConfigLegacy(d, key)
	}

	// Parse rawConfig JSON into a map
	var rawConfig map[string]interface{}
	if err := json.Unmarshal([]byte(rawConfigStr), &rawConfig); err != nil {
		return "", fmt.Errorf("failed to parse rawConfig: %s", err)
	}

	// Inject pki.key
	pki, ok := rawConfig["pki"].(map[string]interface{})
	if !ok {
		pki = map[string]interface{}{}
		rawConfig["pki"] = pki
	}
	pki["key"] = key

	// Marshal to YAML
	yamlBytes, err := yaml.Marshal(rawConfig)
	if err != nil {
		return "", err
	}

	return string(yamlBytes), nil
}

// renderConfigLegacy handles the old decomposed-fields format for backwards compatibility.
func renderConfigLegacy(d map[string]interface{}, key string) (string, error) {
	cfg := newConfig()
	cfg.PKI.CA, _ = d["ca"].(string)
	cfg.PKI.Cert, _ = d["cert"].(string)
	cfg.PKI.Key = key

	i, _ := d["port"].(float64)
	cfg.Listen.Port = int(i)

	cfg.Cipher, _ = d["cipher"].(string)
	// Log verbosity is not required
	if val, _ := d["logVerbosity"].(string); val != "" {
		cfg.Logging.Level = val
	}

	i, _ = d["lhDuration"].(float64)
	cfg.Lighthouse.Interval = int(i)

	if i, ok := d["mtu"].(float64); ok {
		mtu := int(i)
		cfg.Tun.MTU = &mtu
	}

	cfg.Lighthouse.Hosts = make([]string, 0)
	if staticHostmap, ok := d["staticHostmap"].(map[string]interface{}); ok {
		for nebIp, mapping := range staticHostmap {
			def := mapping.(map[string]interface{})

			isLh, _ := def["lighthouse"].(bool)
			if isLh {
				cfg.Lighthouse.Hosts = append(cfg.Lighthouse.Hosts, nebIp)
			}

			hosts, _ := def["destinations"].([]interface{})
			realHosts := make([]string, len(hosts))

			for i, h := range hosts {
				realHosts[i], _ = h.(string)
			}

			cfg.StaticHostmap[nebIp] = realHosts
		}
	}

	if unsafeRoutes, ok := d["unsafeRoutes"].([]interface{}); ok {
		cfg.Tun.UnsafeRoutes = make([]configUnsafeRoute, len(unsafeRoutes))
		for i, r := range unsafeRoutes {
			rawRoute := r.(map[string]interface{})
			route := &cfg.Tun.UnsafeRoutes[i]
			route.Route, _ = rawRoute["route"].(string)
			route.Via, _ = rawRoute["via"].(string)
		}
	}

	finalConfig, err := yaml.Marshal(cfg)
	if err != nil {
		return "", err
	}

	return string(finalConfig), nil
}

// MigrateConfig brings a site config up to CurrentConfigVersion, running whatever chain of
// migrations that takes. Kotlin and Swift call this once per site load and know nothing about
// individual versions, so adding a migration should not need any native changes.
//
// It returns configJSON verbatim when there is nothing to do, which lets callers skip the disk
// write on a plain string comparison.
//
// key is only read when migrating a v0 config. Ask MigrationNeedsKey before going and fetching
// it, on iOS that is a keychain hit we would otherwise take on every site load.
func MigrateConfig(configJSON string, key string) (string, error) {
	version, err := configVersion(configJSON)
	if err != nil {
		return "", err
	}

	if version >= CurrentConfigVersion {
		return configJSON, nil
	}

	result := configJSON

	if version < 1 {
		if result, err = migrateToV1(result, key); err != nil {
			return "", err
		}
	}

	if version < 2 {
		if result, err = migrateToV2(result); err != nil {
			return "", err
		}
	}

	return result, nil
}

// MigrationNeedsKey reports whether migrating this config requires the site's private key. Only
// the v0 format does, since it has to render the legacy config to get a rawConfig.
func MigrationNeedsKey(configJSON string) bool {
	version, err := configVersion(configJSON)
	if err != nil {
		// Let MigrateConfig report the parse failure, meanwhile assume the key is wanted
		return true
	}

	return version < 1
}

// configVersion reads configVersion off a site config. A config without one is a v0.
func configVersion(configJSON string) (int, error) {
	var probe struct {
		ConfigVersion *int `json:"configVersion"`
	}

	if err := json.Unmarshal([]byte(configJSON), &probe); err != nil {
		return 0, fmt.Errorf("failed to parse config: %s", err)
	}

	if probe.ConfigVersion == nil {
		return 0, nil
	}

	return *probe.ConfigVersion, nil
}

// migrateToV1 takes an old-format site JSON (with decomposed fields) and returns a
// new-format site JSON (with rawConfig).
func migrateToV1(oldConfigJSON string, key string) (string, error) {
	var old legacySite
	if err := json.Unmarshal([]byte(oldConfigJSON), &old); err != nil {
		return "", fmt.Errorf("failed to parse old config: %s", err)
	}

	// If it already has a rawConfig from the old managed flow, use that as-is but convert from YAML to JSON
	var rawConfigJSON map[string]interface{}
	if old.RawConfig != nil && *old.RawConfig != "" {
		var err error
		rawConfigJSON, err = yamlToJSONMap([]byte(*old.RawConfig))
		if err != nil {
			return "", fmt.Errorf("failed to parse managed rawConfig YAML: %s", err)
		}
	} else {
		// Render legacy config to YAML, then convert to JSON map
		var d map[string]interface{}
		if err := json.Unmarshal([]byte(oldConfigJSON), &d); err != nil {
			return "", err
		}

		yamlStr, err := renderConfigLegacy(d, key)
		if err != nil {
			return "", fmt.Errorf("failed to render legacy config: %s", err)
		}

		rawConfigJSON, err = yamlToJSONMap([]byte(yamlStr))
		if err != nil {
			return "", fmt.Errorf("failed to convert YAML to JSON: %s", err)
		}
	}

	// Strip pki.key from rawConfig
	if pki, ok := rawConfigJSON["pki"].(map[string]interface{}); ok {
		delete(pki, "key")
	}

	// Preserve dnsResolvers from legacy config under the mobile_nebula namespace
	if old.DnsResolvers != nil && len(*old.DnsResolvers) > 0 {
		mobileNebula, ok := rawConfigJSON["mobile_nebula"].(map[string]interface{})
		if !ok {
			mobileNebula = map[string]interface{}{}
		}
		mobileNebula["dns_resolvers"] = *old.DnsResolvers
		rawConfigJSON["mobile_nebula"] = mobileNebula
	}

	rawConfigBytes, err := json.Marshal(rawConfigJSON)
	if err != nil {
		return "", err
	}

	managed := old.Managed != nil && *old.Managed

	newSite := site{
		Name:              old.Name,
		ID:                old.ID,
		SortKey:           old.SortKey,
		Managed:           managed,
		LastManagedUpdate: old.LastManagedUpdate,
		RawConfig:         string(rawConfigBytes),
		Key:               nil, // Key is stored separately, not in config.json
		ConfigVersion:     1,
		DNCredentials:     nil, // DN credentials are stored separately
	}

	newJSON, err := json.Marshal(newSite)
	if err != nil {
		return "", err
	}

	return string(newJSON), nil
}

// migrateToV2 takes a v1 site JSON and returns a v2 one. It hoists the client owned dns
// settings out of rawConfig.mobile_nebula and up to the top level of the site config.
//
// rawConfig belongs to DN, so mobile_nebula.dns_resolvers is now the admin supplied list and the
// local override lives at the top level next to excludedApps. The old values have to move rather
// than be copied, otherwise a user's resolvers would come back looking like an admin's.
func migrateToV2(configJSON string) (string, error) {
	var site map[string]interface{}
	if err := json.Unmarshal([]byte(configJSON), &site); err != nil {
		return "", fmt.Errorf("failed to parse config: %s", err)
	}

	if rawConfigStr, ok := site["rawConfig"].(string); ok && rawConfigStr != "" {
		var rawConfig map[string]interface{}
		if err := json.Unmarshal([]byte(rawConfigStr), &rawConfig); err != nil {
			return "", fmt.Errorf("failed to parse rawConfig: %s", err)
		}

		if mobileNebula, ok := rawConfig["mobile_nebula"].(map[string]interface{}); ok {
			if v, ok := mobileNebula["dns_resolvers"]; ok {
				site["dnsResolvers"] = v
				delete(mobileNebula, "dns_resolvers")
			}

			if v, ok := mobileNebula["match_domains"]; ok {
				site["matchDomains"] = v
				delete(mobileNebula, "match_domains")
			}

			if len(mobileNebula) == 0 {
				delete(rawConfig, "mobile_nebula")
			}

			rawConfigBytes, err := json.Marshal(rawConfig)
			if err != nil {
				return "", err
			}

			site["rawConfig"] = string(rawConfigBytes)
		}
	}

	site["configVersion"] = CurrentConfigVersion

	newJSON, err := json.Marshal(site)
	if err != nil {
		return "", err
	}

	return string(newJSON), nil
}

// DefaultRawConfig returns a JSON string of the default nebula config.
// Used by Dart when creating new user-configured sites.
func DefaultRawConfig() (string, error) {
	cfg := newConfig()
	// Strip the key since it's stored separately
	cfg.PKI.Key = ""

	yamlBytes, err := yaml.Marshal(cfg)
	if err != nil {
		return "", err
	}

	jsonMap, err := yamlToJSONMap(yamlBytes)
	if err != nil {
		return "", err
	}

	// Strip pki.key
	if pki, ok := jsonMap["pki"].(map[string]interface{}); ok {
		delete(pki, "key")
	}

	jsonBytes, err := json.Marshal(jsonMap)
	if err != nil {
		return "", err
	}

	return string(jsonBytes), nil
}

// YamlToJson converts a YAML string to a JSON string.
// Exported for use by Kotlin/Swift.
func YamlToJson(yamlStr string) (string, error) {
	m, err := yamlToJSONMap([]byte(yamlStr))
	if err != nil {
		return "", err
	}

	jsonBytes, err := json.Marshal(m)
	if err != nil {
		return "", err
	}

	return string(jsonBytes), nil
}

func TestConfig(configData string, key string) error {
	defer func() {
		if r := recover(); r != nil {
			fmt.Println("Recovered in f", r)
		}
	}()

	yamlConfig, err := RenderConfig(configData, key)
	if err != nil {
		return err
	}

	// We don't want to leak the config into the system logs
	l := slog.New(slog.DiscardHandler)

	c := nc.NewC(l)
	err = c.LoadString(yamlConfig)
	if err != nil {
		return fmt.Errorf("failed to load config: %s", err)
	}

	_, err = nebula.Main(c, true, "", l, nil)
	if err != nil {
		switch v := err.(type) {
		case *util.ContextualError:
			return v.Unwrap()
		default:
			return err
		}
	}
	return nil
}

func GetConfigSetting(configData string, setting string) string {
	// We don't want to leak the config into the system logs
	l := slog.New(slog.DiscardHandler)

	c := nc.NewC(l)
	c.LoadString(configData)
	return c.GetString(setting, "")
}

func ParseCIDR(cidr string) (*CIDR, error) {
	p, err := netip.ParsePrefix(cidr)
	if err != nil {
		return nil, err
	}

	if p.Addr().Is4() {
		return &CIDR{
			IPLen:         net.IPv4len,
			Address:       p.Addr().String(),
			SubnetMask:    net.IP(net.CIDRMask(p.Bits(), net.IPv4len*8)).String(),
			PrefixLength:  p.Bits(),
			MaskedAddress: p.Masked().Addr().String(),
		}, nil
	}

	return &CIDR{
		IPLen:         net.IPv6len,
		Address:       p.Addr().String(),
		PrefixLength:  p.Bits(),
		MaskedAddress: p.Masked().Addr().String(),
	}, nil
}

// ParseCerts Returns a JSON representation of 1 or more certificates
func ParseCerts(rawStringCerts string) (string, error) {
	var certs []RawCert
	var c cert.Certificate
	var err error
	rawCerts := []byte(rawStringCerts)

	for {
		c, rawCerts, err = cert.UnmarshalCertificateFromPEM(rawCerts)
		if err != nil {
			return "", err
		}

		rawCert, err := c.MarshalPEM()
		if err != nil {
			return "", err
		}

		rc := RawCert{
			RawCert: string(rawCert),
			Cert:    certToFlatJson(c),
			Validity: Validity{
				Valid: true,
			},
		}

		if c.Expired(time.Now()) {
			rc.Validity.Valid = false
			rc.Validity.Reason = "Certificate is expired"
		}

		if rc.Validity.Valid && c.IsCA() && !c.CheckSignature(c.PublicKey()) {
			rc.Validity.Valid = false
			rc.Validity.Reason = "Certificate signature did not match"
		}

		certs = append(certs, rc)

		if rawCerts == nil || strings.TrimSpace(string(rawCerts)) == "" {
			break
		}
	}

	rawJson, err := json.Marshal(certs)
	if err != nil {
		return "", err
	}

	return string(rawJson), nil
}

// certToFlatJson creates a flat version agnostic representation of a certificate
func certToFlatJson(c cert.Certificate) m {
	cm := m{}

	cm["version"] = c.Version()
	cm["name"] = c.Name()

	// Force list types to not print null
	networks := c.Networks()
	if len(networks) == 0 {
		cm["networks"] = []netip.Prefix{}
	} else {
		cm["networks"] = networks
	}

	unsafeNetworks := c.UnsafeNetworks()
	if len(unsafeNetworks) == 0 {
		cm["unsafeNetworks"] = []netip.Prefix{}
	} else {
		cm["unsafeNetworks"] = unsafeNetworks
	}

	groups := c.Groups()
	if len(groups) == 0 {
		cm["groups"] = []string{}
	} else {
		cm["groups"] = groups
	}

	cm["isCa"] = c.IsCA()
	cm["notBefore"] = c.NotBefore()
	cm["notAfter"] = c.NotAfter()
	cm["issuer"] = c.Issuer()
	cm["publicKey"] = c.PublicKey()
	cm["curve"] = c.Curve().String()
	cm["fingerprint"], _ = c.Fingerprint()
	cm["signature"] = c.Signature()

	return cm
}

func GenerateKeyPair() (string, error) {
	pub, priv, err := x25519Keypair()
	if err != nil {
		return "", err
	}

	kp := KeyPair{}
	kp.PublicKey = string(cert.MarshalPublicKeyToPEM(cert.Curve_CURVE25519, pub))
	kp.PrivateKey = string(cert.MarshalPrivateKeyToPEM(cert.Curve_CURVE25519, priv))

	rawJson, err := json.Marshal(kp)
	if err != nil {
		return "", err
	}

	return string(rawJson), nil
}

func x25519Keypair() ([]byte, []byte, error) {
	var pubkey, privkey [32]byte
	if _, err := io.ReadFull(rand.Reader, privkey[:]); err != nil {
		return nil, nil, err
	}
	curve25519.ScalarBaseMult(&pubkey, &privkey)
	return pubkey[:], privkey[:], nil
}

func VerifyCertAndKey(rawCert string, pemPrivateKey string) (bool, error) {
	rawKey, _, c, err := cert.UnmarshalPrivateKeyFromPEM([]byte(pemPrivateKey))
	if err != nil {
		return false, fmt.Errorf("error while unmarshaling private key: %s", err)
	}

	nebulaCert, _, err := cert.UnmarshalCertificateFromPEM([]byte(rawCert))
	if err != nil {
		return false, fmt.Errorf("error while unmarshaling cert: %s", err)
	}

	if err = nebulaCert.VerifyPrivateKey(c, rawKey); err != nil {
		return false, err
	}

	return true, nil
}
