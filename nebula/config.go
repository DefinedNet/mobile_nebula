package mobileNebula

type config struct {
	PKI           configPKI           `yaml:"pki"`
	StaticHostmap map[string][]string `yaml:"static_host_map"`
	Lighthouse    configLighthouse    `yaml:"lighthouse"`
	Listen        configListen        `yaml:"listen"`
	Punchy        configPunchy        `yaml:"punchy"`
	Cipher        string              `yaml:"cipher"`
	LocalRange    string              `yaml:"local_range"`
	SSHD          configSSHD          `yaml:"sshd"`
	Tun           configTun           `yaml:"tun"`
	Logging       configLogging       `yaml:"logging"`
	Stats         configStats         `yaml:"stats"`
	Handshakes    configHandshakes    `yaml:"handshakes"`
	Firewall      configFirewall      `yaml:"firewall"`
}

func newConfig() *config {
	mtu := 1300
	return &config{
		PKI: configPKI{
			Blacklist: []string{},
		},
		StaticHostmap: map[string][]string{},
		Lighthouse: configLighthouse{
			DNS:      configDNS{},
			Interval: 60,
			Hosts:    []string{},
		},
		Listen: configListen{
			Host:  "0.0.0.0",
			Port:  4242,
			Batch: 64,
		},
		Punchy: configPunchy{
			Punch: true,
			Delay: "1s",
		},
		Cipher: "aes",
		SSHD: configSSHD{
			AuthorizedUsers: []configAuthorizedUser{},
		},
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
		Stats: configStats{},
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
			Inbound: []configFirewallRule{},
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
	ServeDNS     bool      `yaml:"serve_dns"`
	DNS          configDNS `yaml:"dns"`
	Interval     int       `yaml:"interval"`
	Hosts        []string  `yaml:"hosts"`
	//RemoteAllowList map[string]bool        `yaml:"remote_allow_list"`
	//LocalAllowList  map[string]interface{} `yaml:"local_allow_list"` // This can be a special "interfaces" object or a bool
}

type configDNS struct {
	Host string `yaml:"host"`
	Port int    `yaml:"port"`
}

type configListen struct {
	Host        string `yaml:"host"`
	Port        int    `yaml:"port"`
	Batch       int    `yaml:"batch"`
	ReadBuffer  int64  `yaml:"read_buffer"`
	WriteBuffer int64  `yaml:"write_buffer"`
}

type configPunchy struct {
	Punch   bool   `yaml:"punch"`
	Respond bool   `yaml:"respond"`
	Delay   string `yaml:"delay"`
}

type configSSHD struct {
	Enabled         bool                   `yaml:"enabled"`
	Listen          string                 `yaml:"listen"`
	HostKey         string                 `yaml:"host_key"`
	AuthorizedUsers []configAuthorizedUser `yaml:"authorized_users"`
}

type configAuthorizedUser struct {
	Name string   `yaml:"name"`
	Keys []string `yaml:"keys"`
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

type configStats struct {
	Type     string `yaml:"type"`
	Interval string `yaml:"interval"`

	// Graphite settings
	Prefix   string `yaml:"prefix"`
	Protocol string `yaml:"protocol"`
	Host     string `yaml:"host"`

	// Prometheus settings
	Listen    string `yaml:"listen"`
	Path      string `yaml:"path"`
	Namespace string `yaml:"namespace"`
	Subsystem string `yaml:"subsystem"`
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
