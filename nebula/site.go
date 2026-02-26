package mobileNebula

import (
	"encoding/json"
	"io"
	"strconv"
	"time"

	"github.com/DefinedNet/dnapi/keys"
	"github.com/sirupsen/logrus"
	"github.com/slackhq/nebula"
	nc "github.com/slackhq/nebula/config"
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
	InboundRules      []configFirewallRule  `json:"inboundRules"`
	OutboundRules     []configFirewallRule  `json:"outboundRules"`
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

// ruleCollector implements nebula.FirewallInterface to collect firewall rules from nebula's config parser.
type ruleCollector struct {
	inbound  []configFirewallRule
	outbound []configFirewallRule
}

func (rc *ruleCollector) AddRule(incoming bool, proto uint8, startPort int32, endPort int32, groups []string, host string, cidr string, localCidr string, caName string, caSha string) error {
	protoNames := map[uint8]string{0: "any", 1: "icmp", 6: "tcp", 17: "udp"}
	protoStr, ok := protoNames[proto]
	if !ok {
		protoStr = "any"
	}

	var portStr string
	switch {
	case startPort == -1:
		portStr = "fragment"
	case startPort == 0 && endPort == 0:
		portStr = "any"
	case startPort == endPort:
		portStr = strconv.Itoa(int(startPort))
	default:
		portStr = strconv.Itoa(int(startPort)) + "-" + strconv.Itoa(int(endPort))
	}

	rule := configFirewallRule{
		Port:      portStr,
		Proto:     protoStr,
		Host:      host,
		CIDR:      cidr,
		LocalCIDR: localCidr,
		CAName:    caName,
		CASha:     caSha,
	}
	if len(groups) == 1 {
		rule.Group = groups[0]
	} else if len(groups) > 1 {
		rule.Groups = groups
	}
	if incoming {
		rc.inbound = append(rc.inbound, rule)
	} else {
		rc.outbound = append(rc.outbound, rule)
	}
	return nil
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

	// build firewall rules using nebula's config parser
	l := logrus.New()
	l.SetOutput(io.Discard)
	c := nc.NewC(l)
	if err := c.LoadString(strCfg); err != nil {
		return nil, err
	}
	collector := &ruleCollector{
		inbound:  []configFirewallRule{},
		outbound: []configFirewallRule{},
	}
	if err := nebula.AddFirewallRulesFromConfig(l, true, c, collector); err != nil {
		return nil, err
	}
	if err := nebula.AddFirewallRulesFromConfig(l, false, c, collector); err != nil {
		return nil, err
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
		InboundRules:      collector.inbound,
		OutboundRules:     collector.outbound,
		DNCredentials: &dnCredentials{
			HostID:      creds.HostID,
			PrivateKey:  string(pkm),
			Counter:     int(creds.Counter),
			TrustedKeys: string(tkm),
		},
	}, nil
}
