package mobileNebula

import (
	"io"
	"testing"

	"github.com/sirupsen/logrus"
	"github.com/slackhq/nebula"
	nc "github.com/slackhq/nebula/config"
)

func TestRuleCollector(t *testing.T) {
	yamlConfig := `
firewall:
  inbound:
    - port: any
      proto: any
      host: any
    - port: 22
      proto: tcp
      group: engineering
  outbound:
    - port: any
      proto: any
      host: any
`
	l := logrus.New()
	l.SetOutput(io.Discard)
	c := nc.NewC(l)
	if err := c.LoadString(yamlConfig); err != nil {
		t.Fatalf("LoadString error: %v", err)
	}
	collector := &ruleCollector{
		inbound:  []jsonFirewallRule{},
		outbound: []jsonFirewallRule{},
	}
	if err := nebula.AddFirewallRulesFromConfig(l, true, c, collector); err != nil {
		t.Fatalf("Inbound AddFirewallRulesFromConfig error: %v", err)
	}
	if err := nebula.AddFirewallRulesFromConfig(l, false, c, collector); err != nil {
		t.Fatalf("Outbound AddFirewallRulesFromConfig error: %v", err)
	}

	if len(collector.inbound) != 2 {
		t.Fatalf("expected 2 inbound rules, got %d", len(collector.inbound))
	}
	if len(collector.outbound) != 1 {
		t.Fatalf("expected 1 outbound rule, got %d", len(collector.outbound))
	}

	// Check that the second inbound rule has expected values
	r := collector.inbound[1]
	if r.Protocol != "tcp" {
		t.Errorf("expected protocol 'tcp', got '%s'", r.Protocol)
	}
	if r.StartPort != 22 || r.EndPort != 22 {
		t.Errorf("expected startPort=22, endPort=22, got startPort=%d, endPort=%d", r.StartPort, r.EndPort)
	}
	if len(r.Groups) != 1 || r.Groups[0] != "engineering" {
		t.Errorf("expected groups ['engineering'], got %v", r.Groups)
	}
}

func TestConfigFirewallRuleToJSON(t *testing.T) {
	tests := []struct {
		name     string
		input    configFirewallRule
		expected jsonFirewallRule
	}{
		{
			name:  "any/any rule",
			input: configFirewallRule{Port: "any", Proto: "any", Host: "any"},
			expected: jsonFirewallRule{
				Protocol:  "any",
				StartPort: 0,
				EndPort:   0,
				Host:      "any",
			},
		},
		{
			name:  "single port with group",
			input: configFirewallRule{Port: "22", Proto: "tcp", Group: "engineering"},
			expected: jsonFirewallRule{
				Protocol:  "tcp",
				StartPort: 22,
				EndPort:   22,
				Groups:    []string{"engineering"},
			},
		},
		{
			name:  "port range with multiple groups",
			input: configFirewallRule{Port: "80-443", Proto: "tcp", Groups: []string{"eng", "ops"}},
			expected: jsonFirewallRule{
				Protocol:  "tcp",
				StartPort: 80,
				EndPort:   443,
				Groups:    []string{"eng", "ops"},
			},
		},
		{
			name:  "fragment rule",
			input: configFirewallRule{Port: "fragment", Proto: "any", Host: "any"},
			expected: jsonFirewallRule{
				Protocol: "any",
				Fragment: true,
				Host:     "any",
			},
		},
		{
			name:  "cidr and localCidr",
			input: configFirewallRule{Port: "any", Proto: "any", CIDR: "10.0.0.0/8", LocalCIDR: "192.168.0.0/16"},
			expected: jsonFirewallRule{
				Protocol:   "any",
				RemoteCIDR: "10.0.0.0/8",
				LocalCIDR:  "192.168.0.0/16",
			},
		},
		{
			name:  "caName and caSha",
			input: configFirewallRule{Port: "any", Proto: "any", CAName: "my-ca", CASha: "deadbeef"},
			expected: jsonFirewallRule{
				Protocol: "any",
				CAName:   "my-ca",
				CASha:    "deadbeef",
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := tt.input.toJSON()
			if got.Protocol != tt.expected.Protocol {
				t.Errorf("Protocol: got %q, want %q", got.Protocol, tt.expected.Protocol)
			}
			if got.StartPort != tt.expected.StartPort {
				t.Errorf("StartPort: got %d, want %d", got.StartPort, tt.expected.StartPort)
			}
			if got.EndPort != tt.expected.EndPort {
				t.Errorf("EndPort: got %d, want %d", got.EndPort, tt.expected.EndPort)
			}
			if got.Fragment != tt.expected.Fragment {
				t.Errorf("Fragment: got %v, want %v", got.Fragment, tt.expected.Fragment)
			}
			if got.Host != tt.expected.Host {
				t.Errorf("Host: got %q, want %q", got.Host, tt.expected.Host)
			}
			if got.RemoteCIDR != tt.expected.RemoteCIDR {
				t.Errorf("RemoteCIDR: got %q, want %q", got.RemoteCIDR, tt.expected.RemoteCIDR)
			}
			if got.LocalCIDR != tt.expected.LocalCIDR {
				t.Errorf("LocalCIDR: got %q, want %q", got.LocalCIDR, tt.expected.LocalCIDR)
			}
			if got.CAName != tt.expected.CAName {
				t.Errorf("CAName: got %q, want %q", got.CAName, tt.expected.CAName)
			}
			if got.CASha != tt.expected.CASha {
				t.Errorf("CASha: got %q, want %q", got.CASha, tt.expected.CASha)
			}
			if len(got.Groups) != len(tt.expected.Groups) {
				t.Errorf("Groups length: got %d, want %d", len(got.Groups), len(tt.expected.Groups))
			} else {
				for i := range got.Groups {
					if got.Groups[i] != tt.expected.Groups[i] {
						t.Errorf("Groups[%d]: got %q, want %q", i, got.Groups[i], tt.expected.Groups[i])
					}
				}
			}
		})
	}
}

func TestJSONFirewallRuleToConfig(t *testing.T) {
	tests := []struct {
		name     string
		input    jsonFirewallRule
		expected configFirewallRule
	}{
		{
			name:  "any/any rule",
			input: jsonFirewallRule{Protocol: "any", StartPort: 0, EndPort: 0, Host: "any"},
			expected: configFirewallRule{
				Proto: "any",
				Port:  "any",
				Host:  "any",
			},
		},
		{
			name:  "single port with single group",
			input: jsonFirewallRule{Protocol: "tcp", StartPort: 22, EndPort: 22, Groups: []string{"engineering"}},
			expected: configFirewallRule{
				Proto: "tcp",
				Port:  "22",
				Group: "engineering",
			},
		},
		{
			name:  "port range with multiple groups",
			input: jsonFirewallRule{Protocol: "tcp", StartPort: 80, EndPort: 443, Groups: []string{"eng", "ops"}},
			expected: configFirewallRule{
				Proto:  "tcp",
				Port:   "80-443",
				Groups: []string{"eng", "ops"},
			},
		},
		{
			name:  "fragment rule",
			input: jsonFirewallRule{Protocol: "any", Fragment: true, Host: "any"},
			expected: configFirewallRule{
				Proto: "any",
				Port:  "fragment",
				Host:  "any",
			},
		},
		{
			name:  "cidrs",
			input: jsonFirewallRule{Protocol: "any", RemoteCIDR: "10.0.0.0/8", LocalCIDR: "192.168.0.0/16"},
			expected: configFirewallRule{
				Proto:     "any",
				Port:      "any",
				CIDR:      "10.0.0.0/8",
				LocalCIDR: "192.168.0.0/16",
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := tt.input.toConfig()
			if got.Proto != tt.expected.Proto {
				t.Errorf("Proto: got %q, want %q", got.Proto, tt.expected.Proto)
			}
			if got.Port != tt.expected.Port {
				t.Errorf("Port: got %q, want %q", got.Port, tt.expected.Port)
			}
			if got.Host != tt.expected.Host {
				t.Errorf("Host: got %q, want %q", got.Host, tt.expected.Host)
			}
			if got.Group != tt.expected.Group {
				t.Errorf("Group: got %q, want %q", got.Group, tt.expected.Group)
			}
			if got.CIDR != tt.expected.CIDR {
				t.Errorf("CIDR: got %q, want %q", got.CIDR, tt.expected.CIDR)
			}
			if got.LocalCIDR != tt.expected.LocalCIDR {
				t.Errorf("LocalCIDR: got %q, want %q", got.LocalCIDR, tt.expected.LocalCIDR)
			}
			if len(got.Groups) != len(tt.expected.Groups) {
				t.Errorf("Groups length: got %d, want %d", len(got.Groups), len(tt.expected.Groups))
			} else {
				for i := range got.Groups {
					if got.Groups[i] != tt.expected.Groups[i] {
						t.Errorf("Groups[%d]: got %q, want %q", i, got.Groups[i], tt.expected.Groups[i])
					}
				}
			}
		})
	}
}

func TestRoundTrip(t *testing.T) {
	original := configFirewallRule{
		Port:      "80-443",
		Proto:     "tcp",
		Host:      "any",
		Group:     "engineering",
		CIDR:      "10.0.0.0/8",
		LocalCIDR: "192.168.0.0/16",
		CAName:    "my-ca",
		CASha:     "deadbeef",
	}

	roundTripped := original.toJSON().toConfig()

	if roundTripped.Proto != original.Proto {
		t.Errorf("Proto: got %q, want %q", roundTripped.Proto, original.Proto)
	}
	if roundTripped.Port != original.Port {
		t.Errorf("Port: got %q, want %q", roundTripped.Port, original.Port)
	}
	if roundTripped.Host != original.Host {
		t.Errorf("Host: got %q, want %q", roundTripped.Host, original.Host)
	}
	// Single group round-trips back to Group (singular)
	if roundTripped.Group != original.Group {
		t.Errorf("Group: got %q, want %q", roundTripped.Group, original.Group)
	}
	if roundTripped.CIDR != original.CIDR {
		t.Errorf("CIDR: got %q, want %q", roundTripped.CIDR, original.CIDR)
	}
	if roundTripped.LocalCIDR != original.LocalCIDR {
		t.Errorf("LocalCIDR: got %q, want %q", roundTripped.LocalCIDR, original.LocalCIDR)
	}
	if roundTripped.CAName != original.CAName {
		t.Errorf("CAName: got %q, want %q", roundTripped.CAName, original.CAName)
	}
	if roundTripped.CASha != original.CASha {
		t.Errorf("CASha: got %q, want %q", roundTripped.CASha, original.CASha)
	}
}
