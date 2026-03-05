package mobileNebula

import (
	"encoding/json"
	"time"

	"github.com/DefinedNet/dnapi/keys"
	"gopkg.in/yaml.v2"
)

// site represents an IncomingSite in Kotlin/Swift.
type site struct {
	Name              string         `json:"name"`
	ID                string         `json:"id"`
	SortKey           *int           `json:"sortKey"`
	Managed           bool           `json:"managed"`
	LastManagedUpdate *time.Time     `json:"lastManagedUpdate"`
	RawConfig         string         `json:"rawConfig"`
	Key               *string        `json:"key"`
	DNCredentials     *dnCredentials `json:"dnCredentials"`
	ConfigVersion     int            `json:"configVersion"`
}

type dnCredentials struct {
	HostID      string `json:"hostID"`
	PrivateKey  string `json:"privateKey"`
	Counter     int    `json:"counter"`
	TrustedKeys string `json:"trustedKeys"`
}

func newDNSite(name string, rawCfg []byte, key string, creds keys.Credentials) (*site, error) {
	// Convert YAML Nebula config to a JSON rawConfig, stripping the private key
	rawConfigJSON, err := yamlToJSONMap(rawCfg)
	if err != nil {
		return nil, err
	}

	// Strip pki.key from rawConfig — key is stored separately
	if pki, ok := rawConfigJSON["pki"].(map[string]interface{}); ok {
		delete(pki, "key")
	}

	rawConfigBytes, err := json.Marshal(rawConfigJSON)
	if err != nil {
		return nil, err
	}

	now := time.Now()

	pkm, err := creds.PrivateKey.MarshalPEM()
	if err != nil {
		return nil, err
	}

	tkm, err := keys.TrustedKeysToPEM(creds.TrustedKeys)
	if err != nil {
		return nil, err
	}

	return &site{
		Name:              name,
		ID:                creds.HostID,
		SortKey:           nil,
		Managed:           true,
		LastManagedUpdate: &now,
		RawConfig:         string(rawConfigBytes),
		Key:               &key,
		ConfigVersion:     1,
		DNCredentials: &dnCredentials{
			HostID:      creds.HostID,
			PrivateKey:  string(pkm),
			Counter:     int(creds.Counter),
			TrustedKeys: string(tkm),
		},
	}, nil
}

// yamlToJSONMap converts a YAML byte slice to a map[string]interface{} suitable for JSON marshaling.
// It normalizes map[interface{}]interface{} (Go yaml output) to map[string]interface{}.
func yamlToJSONMap(yamlBytes []byte) (map[string]interface{}, error) {
	var raw interface{}
	if err := yaml.Unmarshal(yamlBytes, &raw); err != nil {
		return nil, err
	}

	normalized := normalizeYamlValue(raw)
	if m, ok := normalized.(map[string]interface{}); ok {
		return m, nil
	}
	return map[string]interface{}{}, nil
}

// normalizeYamlValue recursively converts map[interface{}]interface{} to map[string]interface{}
// so the result can be marshaled to JSON.
func normalizeYamlValue(v interface{}) interface{} {
	switch val := v.(type) {
	case map[interface{}]interface{}:
		m := make(map[string]interface{}, len(val))
		for k, v := range val {
			key, _ := k.(string)
			m[key] = normalizeYamlValue(v)
		}
		return m
	case map[string]interface{}:
		m := make(map[string]interface{}, len(val))
		for k, v := range val {
			m[k] = normalizeYamlValue(v)
		}
		return m
	case []interface{}:
		a := make([]interface{}, len(val))
		for i, v := range val {
			a[i] = normalizeYamlValue(v)
		}
		return a
	default:
		return v
	}
}

// Legacy types kept for MigrateConfig support.

type legacySite struct {
	Name              string                      `json:"name"`
	ID                string                      `json:"id"`
	StaticHostmap     map[string]legacyStaticHost `json:"staticHostmap"`
	UnsafeRoutes      *[]legacyUnsafeRoute        `json:"unsafeRoutes"`
	Cert              string                      `json:"cert"`
	CA                string                      `json:"ca"`
	LHDuration        int                         `json:"lhDuration"`
	Port              int                         `json:"port"`
	MTU               *int                        `json:"mtu"`
	Cipher            string                      `json:"cipher"`
	SortKey           *int                        `json:"sortKey"`
	LogVerbosity      *string                     `json:"logVerbosity"`
	Key               *string                     `json:"key"`
	Managed           *bool                       `json:"managed"`
	LastManagedUpdate *time.Time                  `json:"lastManagedUpdate"`
	RawConfig         *string                     `json:"rawConfig"`
	DNCredentials     *dnCredentials              `json:"dnCredentials"`
	DnsResolvers      *[]string                   `json:"dnsResolvers"`
	AlwaysOn          *bool                       `json:"alwaysOn"`
}

type legacyStaticHost struct {
	Lighthouse   bool     `json:"lighthouse"`
	Destinations []string `json:"destinations"`
}

type legacyUnsafeRoute struct {
	Route string `json:"route"`
	Via   string `json:"via"`
	MTU   *int   `json:"mtu"`
}
