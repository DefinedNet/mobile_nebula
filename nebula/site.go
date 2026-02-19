package mobileNebula

import (
	"encoding/json"
	"strconv"
	"strings"
	"time"

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
	RawConfig         *string               `json:"rawConfig"`
	DNCredentials     *dnCredentials        `json:"dnCredentials"`
	InboundRules     []firewallRule        `json:"inboundRules"`
	OutboundRules     []firewallRule        `json:"outboundRules"`
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

type firewallRule struct {
	Protocol   string   `json:"protocol"`
	StartPort  int      `json:"startPort"`
	EndPort    int      `json:"endPort"`
	Fragment   *bool    `json:"fragment"`
	Host       *string  `json:"host"`
	Groups     []string `json:"groups"`
	LocalCIDR  *string  `json:"localCidr"`
	RemoteCIDR *string  `json:"remoteCidr"`
	CAName     *string  `json:"caName"`
	CASha      *string  `json:"caSha"`
}

func fromConfigFirewallRule(r configFirewallRule) firewallRule {
	rule := firewallRule{
		Protocol: r.Proto,
	}

	port := strings.TrimSpace(r.Port)
	switch {
	case port == "" || strings.ToLower(port) == "any":
		rule.StartPort = 0
		rule.EndPort = 0
	case strings.ToLower(port) == "fragment":
		frag := true
		rule.Fragment = &frag
	case strings.Contains(port, "-"):
		parts := strings.SplitN(port, "-", 2)
		rule.StartPort, _ = strconv.Atoi(strings.TrimSpace(parts[0]))
		rule.EndPort, _ = strconv.Atoi(strings.TrimSpace(parts[1]))
	default:
		p, _ := strconv.Atoi(port)
		rule.StartPort = p
		rule.EndPort = p
	}

	if r.Host != "" {
		h := r.Host
		rule.Host = &h
	}
	if r.Group != "" {
		rule.Groups = []string{r.Group}
	} else if len(r.Groups) > 0 {
		rule.Groups = r.Groups
	}
	if r.CIDR != "" {
		c := r.CIDR
		rule.RemoteCIDR = &c
	}
	if r.LocalCIDR != "" {
		c := r.LocalCIDR
		rule.LocalCIDR = &c
	}
	if r.CASha != "" {
		s := r.CASha
		rule.CASha = &s
	}
	if r.CAName != "" {
		n := r.CAName
		rule.CAName = &n
	}

	return rule
}

func toConfigFirewallRule(r firewallRule) configFirewallRule {
	rule := configFirewallRule{
		Proto: r.Protocol,
	}

	if r.Fragment != nil && *r.Fragment {
		rule.Port = "fragment"
	} else if r.StartPort == 0 && r.EndPort == 0 {
		rule.Port = "any"
	} else if r.StartPort == r.EndPort {
		rule.Port = strconv.Itoa(r.StartPort)
	} else {
		rule.Port = strconv.Itoa(r.StartPort) + "-" + strconv.Itoa(r.EndPort)
	}

	if r.Host != nil {
		rule.Host = *r.Host
	}
	if len(r.Groups) == 1 {
		rule.Group = r.Groups[0]
	} else if len(r.Groups) > 1 {
		rule.Groups = r.Groups
	}
	if r.RemoteCIDR != nil {
		rule.CIDR = *r.RemoteCIDR
	}
	if r.LocalCIDR != nil {
		rule.LocalCIDR = *r.LocalCIDR
	}
	if r.CASha != nil {
		rule.CASha = *r.CASha
	}
	if r.CAName != nil {
		rule.CAName = *r.CAName
	}

	return rule
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

func newDNSite(name string, rawCfg []byte, key string, creds keys.Credentials) (*site, error) {
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

	// build firewall rules
	inboundRules := make([]firewallRule, len(cfg.Firewall.Inbound))
	for i, r := range cfg.Firewall.Inbound {
		inboundRules[i] = fromConfigFirewallRule(r)
	}
	outboundRules := make([]firewallRule, len(cfg.Firewall.Outbound))
	for i, r := range cfg.Firewall.Outbound {
		outboundRules[i] = fromConfigFirewallRule(r)
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

	return &site{
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
		InboundRules:     inboundRules,
		OutboundRules:     outboundRules,
		DNCredentials: &dnCredentials{
			HostID:      creds.HostID,
			PrivateKey:  string(pkm),
			Counter:     int(creds.Counter),
			TrustedKeys: string(tkm),
		},
	}, nil
}
