package mobileNebula

import (
	"bytes"
	"crypto/rand"
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"net"
	"strings"
	"time"

	"github.com/DefinedNet/dnapi"
	"github.com/sirupsen/logrus"
	"github.com/slackhq/nebula"
	"github.com/slackhq/nebula/cert"
	nc "github.com/slackhq/nebula/config"
	"github.com/slackhq/nebula/util"
	"golang.org/x/crypto/curve25519"
	"gopkg.in/yaml.v2"
)

type m map[string]interface{}

type CIDR struct {
	Ip       string
	MaskCIDR string
	MaskSize int
	Network  string
}

type Validity struct {
	Valid  bool
	Reason string
}

type RawCert struct {
	RawCert  string
	Cert     *cert.NebulaCertificate
	Validity Validity
}

type KeyPair struct {
	PublicKey  string
	PrivateKey string
}

func RenderConfig(configData string, key string) (string, error) {
	var d m

	err := json.Unmarshal([]byte(configData), &d)
	if err != nil {
		return "", err
	}

	// If this is a managed config, go ahead and return it
	if rawCfg, ok := d["rawConfig"].(string); ok {
		yamlCfg, err := dnapi.InsertConfigPrivateKey([]byte(rawCfg), []byte(key))
		if err != nil {
			return "", err
		}
		return "# Managed Nebula Config (defined.net)\n" + string(yamlCfg), nil
	}

	// Otherwise, build the config
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
	staticHostmap := d["staticHostmap"].(map[string]interface{})
	for nebIp, mapping := range staticHostmap {
		def := mapping.(map[string]interface{})

		isLh := def["lighthouse"].(bool)
		if isLh {
			cfg.Lighthouse.Hosts = append(cfg.Lighthouse.Hosts, nebIp)
		}

		hosts := def["destinations"].([]interface{})
		realHosts := make([]string, len(hosts))

		for i, h := range hosts {
			realHosts[i] = h.(string)
		}

		cfg.StaticHostmap[nebIp] = realHosts
	}

	if unsafeRoutes, ok := d["unsafeRoutes"].([]interface{}); ok {
		cfg.Tun.UnsafeRoutes = make([]configUnsafeRoute, len(unsafeRoutes))
		for i, r := range unsafeRoutes {
			rawRoute := r.(map[string]interface{})
			route := &cfg.Tun.UnsafeRoutes[i]
			route.Route = rawRoute["route"].(string)
			route.Via = rawRoute["via"].(string)
		}
	}

	if dnsResolvers, ok := d["dnsResolvers"].([]interface{}); ok {
		cfg.Tun.DNSResolvers = make([]string, len(dnsResolvers))
		for i, r := range dnsResolvers {
			cfg.Tun.DNSResolvers[i] = r.(string)
		}
	}

	finalConfig, err := yaml.Marshal(cfg)
	if err != nil {
		return "", err
	}

	return string(finalConfig), nil
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
	l := logrus.New()
	l.SetOutput(bytes.NewBuffer([]byte{}))

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
	l := logrus.New()
	l.SetOutput(ioutil.Discard)

	c := nc.NewC(l)
	c.LoadString(configData)
	return c.GetString(setting, "")
}

func ParseCIDR(cidr string) (*CIDR, error) {
	ip, ipNet, err := net.ParseCIDR(cidr)
	if err != nil {
		return nil, err
	}
	size, _ := ipNet.Mask.Size()

	return &CIDR{
		Ip:       ip.String(),
		MaskCIDR: fmt.Sprintf("%d.%d.%d.%d", ipNet.Mask[0], ipNet.Mask[1], ipNet.Mask[2], ipNet.Mask[3]),
		MaskSize: size,
		Network:  ipNet.IP.String(),
	}, nil
}

// Returns a JSON representation of 1 or more certificates
func ParseCerts(rawStringCerts string) (string, error) {
	var certs []RawCert
	var c *cert.NebulaCertificate
	var err error
	rawCerts := []byte(rawStringCerts)

	for {
		c, rawCerts, err = cert.UnmarshalNebulaCertificateFromPEM(rawCerts)
		if err != nil {
			return "", err
		}

		rawCert, err := c.MarshalToPEM()
		if err != nil {
			return "", err
		}

		rc := RawCert{
			RawCert: string(rawCert),
			Cert:    c,
			Validity: Validity{
				Valid: true,
			},
		}

		if c.Expired(time.Now()) {
			rc.Validity.Valid = false
			rc.Validity.Reason = "Certificate is expired"
		}

		if rc.Validity.Valid && c.Details.IsCA && !c.CheckSignature(c.Details.PublicKey) {
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

func GenerateKeyPair() (string, error) {
	pub, priv, err := x25519Keypair()
	if err != nil {
		return "", err
	}

	kp := KeyPair{}
	kp.PublicKey = string(cert.MarshalX25519PublicKey(pub))
	kp.PrivateKey = string(cert.MarshalX25519PrivateKey(priv))

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
	rawKey, _, err := cert.UnmarshalX25519PrivateKey([]byte(pemPrivateKey))
	if err != nil {
		return false, fmt.Errorf("error while unmarshaling private key: %s", err)
	}

	nebulaCert, _, err := cert.UnmarshalNebulaCertificateFromPEM([]byte(rawCert))
	if err != nil {
		return false, fmt.Errorf("error while unmarshaling cert: %s", err)
	}

	if err = nebulaCert.VerifyPrivateKey(nebulaCert.Details.Curve, rawKey); err != nil {
		return false, err
	}

	return true, nil
}
