package mobileNebula

import (
	"encoding/json"
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
		inbound:  []configFirewallRule{},
		outbound: []configFirewallRule{},
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
	if r.Proto != "tcp" {
		t.Errorf("expected proto 'tcp', got '%s'", r.Proto)
	}
	if r.Port != "22" {
		t.Errorf("expected port '22', got '%s'", r.Port)
	}
	if r.Group != "engineering" {
		t.Errorf("expected group 'engineering', got '%s'", r.Group)
	}
}

func TestParseFirewallRules(t *testing.T) {
	yamlConfig := `
firewall:
  inbound:
    - port: any
      proto: any
      host: any
    - port: 22
      proto: tcp
      group: engineering
    - port: 443
      proto: tcp
      groups:
        - engineering
        - admins
      local_cidr: 10.0.0.0/8
  outbound:
    - port: any
      proto: any
      host: any
`
	result, err := ParseFirewallRules(yamlConfig)
	if err != nil {
		t.Fatalf("ParseFirewallRules error: %v", err)
	}

	var parsed struct {
		InboundRules  []configFirewallRule `json:"inboundRules"`
		OutboundRules []configFirewallRule `json:"outboundRules"`
	}
	if err := json.Unmarshal([]byte(result), &parsed); err != nil {
		t.Fatalf("failed to unmarshal result: %v", err)
	}

	if len(parsed.InboundRules) != 3 {
		t.Fatalf("expected 3 inbound rules, got %d", len(parsed.InboundRules))
	}
	if len(parsed.OutboundRules) != 1 {
		t.Fatalf("expected 1 outbound rule, got %d", len(parsed.OutboundRules))
	}

	// Check the third inbound rule has groups and local_cidr
	r := parsed.InboundRules[2]
	if r.Proto != "tcp" {
		t.Errorf("expected proto 'tcp', got '%s'", r.Proto)
	}
	if r.Port != "443" {
		t.Errorf("expected port '443', got '%s'", r.Port)
	}
	if len(r.Groups) != 2 {
		t.Errorf("expected 2 groups, got %d", len(r.Groups))
	}
	if r.LocalCIDR != "10.0.0.0/8" {
		t.Errorf("expected localCidr '10.0.0.0/8', got '%s'", r.LocalCIDR)
	}
}

func TestParseFirewallRulesNoFirewall(t *testing.T) {
	yamlConfig := `
pki:
  ca: test
`
	result, err := ParseFirewallRules(yamlConfig)
	if err != nil {
		t.Fatalf("ParseFirewallRules error: %v", err)
	}

	var parsed struct {
		InboundRules  []configFirewallRule `json:"inboundRules"`
		OutboundRules []configFirewallRule `json:"outboundRules"`
	}
	if err := json.Unmarshal([]byte(result), &parsed); err != nil {
		t.Fatalf("failed to unmarshal result: %v", err)
	}

	if len(parsed.InboundRules) != 0 {
		t.Errorf("expected 0 inbound rules, got %d", len(parsed.InboundRules))
	}
	if len(parsed.OutboundRules) != 0 {
		t.Errorf("expected 0 outbound rules, got %d", len(parsed.OutboundRules))
	}
}
