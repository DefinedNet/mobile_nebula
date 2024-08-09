package mobileNebula

type config struct {
	PKI           configPKI           `yaml:"pki"`
	StaticHostmap map[string][]string `yaml:"static_host_map"`
	Lighthouse    configLighthouse    `yaml:"lighthouse"`
	Listen        configListen        `yaml:"listen"`
	Punchy        configPunchy        `yaml:"punchy"`
	Cipher        string              `yaml:"cipher"`
	LocalRange    string              `yaml:"local_range"`
	Tun           configTun           `yaml:"tun"`
	Logging       configLogging       `yaml:"logging"`
	Handshakes    configHandshakes    `yaml:"handshakes"`
	Firewall      configFirewall      `yaml:"firewall"`
	Relay         configRelay         `yaml:"relay"`
}

func newConfig() *config {
	mtu := 1300
	return &config{
		PKI: configPKI{
			Blacklist: []string{},
		},
		StaticHostmap: map[string][]string{},
		Lighthouse: configLighthouse{
			Interval: 60,
			Hosts:    []string{},
		},
		Listen: configListen{
			Host:  "::",
			Port:  0,
		},
		Punchy: configPunchy{
			Punch: true,
			Delay: "1s",
		},
		Relay: configRelay{
			UseRelays: true,
		},
		Cipher: "aes",
		Tun: configTun{
			Dev:                "tun1",
			DropLocalbroadcast: true,
			DropMulticast:      true,
			TxQueue:            500,
			MTU:                &mtu,
			Routes:             []configRoute{},
			UnsafeRoutes:       []configUnsafeRoute{},
		},
		Logging: configLogging{
			Level:  "info",
			Format: "text",
		},
		Handshakes: configHandshakes{
			TryInterval:  "100ms",
			Retries:      20,
			WaitRotation: 5,
		},
		Firewall: configFirewall{
			Conntrack: configConntrack{
				TcpTimeout:     "120h",
				UdpTimeout:     "3m",
				DefaultTimeout: "10m",
				MaxConnections: 100000,
			},
			Outbound: []configFirewallRule{
				{
					Port:  "any",
					Proto: "any",
					Host:  "any",
				},
			},
			Inbound: []configFirewallRule{
				{
					Port:  "any",
					Proto: "icmp",
					Host:  "any",
				},
				{
					Port:  "8080",
					Proto: "any",
					Host:  "any",
				},
			},
		},
	}
}

type configPKI struct {
	CA        string   `yaml:"ca"`
	Cert      string   `yaml:"cert"`
	Key       string   `yaml:"key"`
	Blacklist []string `yaml:"blacklist"`
}

type configLighthouse struct {
	AmLighthouse bool      `yaml:"am_lighthouse"`
	Interval     int       `yaml:"interval"`
	Hosts        []string  `yaml:"hosts"`
	//RemoteAllowList map[string]bool        `yaml:"remote_allow_list"`
	//LocalAllowList  map[string]interface{} `yaml:"local_allow_list"` // This can be a special "interfaces" object or a bool
}

type configListen struct {
	Host        string `yaml:"host"`
	Port        int    `yaml:"port"`
}

type configPunchy struct {
	Punch   bool   `yaml:"punch"`
	Respond bool   `yaml:"respond"`
	Delay   string `yaml:"delay"`
}

type configTun struct {
	Dev                string              `yaml:"dev"`
	DropLocalbroadcast bool                `yaml:"drop_local_broadcast"`
	DropMulticast      bool                `yaml:"drop_multicast"`
	TxQueue            int                 `yaml:"tx_queue"`
	MTU                *int                `yaml:"mtu,omitempty"`
	Routes             []configRoute       `yaml:"routes"`
	UnsafeRoutes       []configUnsafeRoute `yaml:"unsafe_routes"`
}

type configRoute struct {
	MTU   int    `yaml:"mtu"`
	Route string `yaml:"route"`
}

type configUnsafeRoute struct {
	MTU   *int   `yaml:"mtu,omitempty"`
	Route string `yaml:"route"`
	Via   string `yaml:"via"`
}

type configLogging struct {
	Level           string `yaml:"level"`
	Format          string `yaml:"format"`
	TimestampFormat string `yaml:"timestamp_format,omitempty"`
}

type configHandshakes struct {
	TryInterval  string `yaml:"try_interval"`
	Retries      int    `yaml:"retries"`
	WaitRotation int    `yaml:"wait_rotation"`
}

type configFirewall struct {
	Conntrack configConntrack      `yaml:"conntrack"`
	Outbound  []configFirewallRule `yaml:"outbound"`
	Inbound   []configFirewallRule `yaml:"inbound"`
}

type configConntrack struct {
	TcpTimeout     string `yaml:"tcp_timeout"`
	UdpTimeout     string `yaml:"udp_timeout"`
	DefaultTimeout string `yaml:"default_timeout"`
	MaxConnections int    `yaml:"max_connections"`
}

type configFirewallRule struct {
	Port   string   `yaml:"port,omitempty"`
	Code   string   `yaml:"code,omitempty"`
	Proto  string   `yaml:"proto,omitempty"`
	Host   string   `yaml:"host,omitempty"`
	Group  string   `yaml:"group,omitempty"`
	Groups []string `yaml:"groups,omitempty"`
	CIDR   string   `yaml:"cidr,omitempty"`
	CASha  string   `yaml:"ca_sha,omitempty"`
	CAName string   `yaml:"ca_name,omitempty"`
}

type configRelay struct {
	AmRelay   bool     `yaml:"am_relay,omitempty"`
	UseRelays bool     `yaml:"use_relays"`
	relays    []string `yaml:"relays,omitempty"`
}
