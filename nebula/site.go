package mobileNebula

import (
	"encoding/json"
	"time"

	"github.com/DefinedNet/dnapi"
	"github.com/DefinedNet/dnapi/keys"
	"gopkg.in/yaml.v2"
)

// Site represents an IncomingSite in Kotlin/Swift.
type site struct {
	Name              string                `json:"name"`
	ID                string                `json:"id"`
	StaticHostmap     map[string]staticHost `json:"staticHostmap"`
	UnsafeRoutes      *[]unsafeRoute        `json:"unsafeRoutes"`
	Cert              string                `json:"cert"`
	CA                string                `json:"ca"`
	LHDuration        int                   `json:"lhDuration"`
	Port              int                   `json:"port"`
	MTU               *int                  `json:"mtu"`
	Cipher            string                `json:"cipher"`
	SortKey           *int                  `json:"sortKey"`
	LogVerbosity      *string               `json:"logVerbosity"`
	Key               *string               `json:"key"`
	Managed           jsonTrue              `json:"managed"`
	LastManagedUpdate *time.Time            `json:"lastManagedUpdate"`
	ManagedOIDCEmail  *string               `json:"managedOIDCEmail"`
	ManagedOIDCExpiry *time.Time            `json:"managedOIDCExpiry"`
	RawConfig         *string               `json:"rawConfig"`
	DNCredentials     *dnCredentials        `json:"dnCredentials"`
}

type staticHost struct {
	Lighthouse   bool     `json:"lighthouse"`
	Destinations []string `json:"destinations"`
}

type unsafeRoute struct {
	Route string `json:"route"`
	Via   string `json:"via"`
	MTU   *int   `json:"mtu"`
}

type dnCredentials struct {
	HostID      string `json:"hostID"`
	PrivateKey  string `json:"privateKey"`
	Counter     int    `json:"counter"`
	TrustedKeys string `json:"trustedKeys"`
}

// jsonTrue always marshals to true.
type jsonTrue bool

func (f jsonTrue) MarshalJSON() ([]byte, error) {
	return json.Marshal(true)
}

func newDNSite(name string, rawCfg []byte, key string, creds keys.Credentials, configMeta *dnapi.ConfigMeta) (*site, error) {
	// Convert YAML Nebula config to a JSON Site
	var cfg config
	if err := yaml.Unmarshal(rawCfg, &cfg); err != nil {
		return nil, err
	}

	strCfg := string(rawCfg)

	// build static hostmap
	shm := map[string]staticHost{}
	for vpnIP, remoteIPs := range cfg.StaticHostmap {
		sh := staticHost{Destinations: remoteIPs}
		shm[vpnIP] = sh
	}
	for _, vpnIP := range cfg.Lighthouse.Hosts {
		if sh, ok := shm[vpnIP]; ok {
			sh.Lighthouse = true
			shm[vpnIP] = sh
		} else {
			shm[vpnIP] = staticHost{Lighthouse: true}
		}
	}

	// build unsafe routes
	ur := []unsafeRoute{}
	for _, canon := range cfg.Tun.UnsafeRoutes {
		ur = append(ur, unsafeRoute{
			Route: canon.Route,
			Via:   canon.Via,
			MTU:   canon.MTU,
		})
	}

	// log verbosity is nullable
	var logVerb *string
	if cfg.Logging.Level != "" {
		v := cfg.Logging.Level
		logVerb = &v
	}

	// TODO the mobile app requires an explicit cipher or it will display an error
	cipher := cfg.Cipher
	if cipher == "" {
		cipher = "aes"
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

	s := &site{
		Name:              name,
		ID:                creds.HostID,
		StaticHostmap:     shm,
		UnsafeRoutes:      &ur,
		Cert:              cfg.PKI.Cert,
		CA:                cfg.PKI.CA,
		LHDuration:        cfg.Lighthouse.Interval,
		Port:              cfg.Listen.Port,
		MTU:               cfg.Tun.MTU,
		Cipher:            cipher,
		SortKey:           nil,
		LogVerbosity:      logVerb,
		Key:               &key,
		Managed:           true,
		LastManagedUpdate: &now,
		RawConfig:         &strCfg,
		DNCredentials: &dnCredentials{
			HostID:      creds.HostID,
			PrivateKey:  string(pkm),
			Counter:     int(creds.Counter),
			TrustedKeys: string(tkm),
		},
	}

	if configMeta != nil && configMeta.EndpointOIDC != nil {
		s.ManagedOIDCEmail = &configMeta.EndpointOIDC.Email
		s.ManagedOIDCExpiry = configMeta.EndpointOIDC.ExpiresAt
	}

	return s, nil
}
