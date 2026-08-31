package mobileNebula

import (
	"encoding/json"
	"fmt"
)

// effectiveDNS is the DNS configuration a platform layer should apply for a
// site. An empty Resolvers list means DNS should not be configured.
type effectiveDNS struct {
	Resolvers     []string `json:"resolvers"`
	MatchDomains  []string `json:"matchDomains"`
	SearchDomains []string `json:"searchDomains"`
	// Source records which channel won: "override", "managed", or "manual".
	Source string `json:"source"`
}

// dnsOverride is the device-local DNS override, stored as a client-only
// top-level site field so it survives managed config updates. The explicit
// Enabled flag (rather than non-empty resolvers as the signal) lets a user
// disable managed DNS on this device without substituting their own resolvers.
type dnsOverride struct {
	Enabled       bool     `json:"enabled"`
	Resolvers     []string `json:"resolvers"`
	MatchDomains  []string `json:"matchDomains"`
	SearchDomains []string `json:"searchDomains"`
}

// EffectiveDNS resolves the DNS settings a platform should apply for a site
// from its site JSON. Precedence: the device-local dnsOverride when enabled,
// else the managed definednet.dns block from rawConfig (non-empty
// resolver_addrs is the install signal, matching dnclient), else the manual
// mobile_nebula settings from rawConfig. Returns a JSON object:
//
//	{"resolvers": [...], "matchDomains": [...], "searchDomains": [...], "source": "..."}
func EffectiveDNS(siteJSON string) (string, error) {
	var s struct {
		RawConfig   string       `json:"rawConfig"`
		DNSOverride *dnsOverride `json:"dnsOverride"`
	}
	if err := json.Unmarshal([]byte(siteJSON), &s); err != nil {
		return "", fmt.Errorf("failed to parse site JSON: %s", err)
	}

	var rawConfig map[string]any
	if s.RawConfig != "" {
		if err := json.Unmarshal([]byte(s.RawConfig), &rawConfig); err != nil {
			return "", fmt.Errorf("failed to parse rawConfig: %s", err)
		}
	}

	result := effectiveDNS{Source: "manual"}

	if s.DNSOverride != nil && s.DNSOverride.Enabled {
		// Enabled with empty resolvers deliberately disables DNS on this device.
		result.Source = "override"
		result.Resolvers = s.DNSOverride.Resolvers
		result.MatchDomains = s.DNSOverride.MatchDomains
		result.SearchDomains = s.DNSOverride.SearchDomains
	} else if dns := getMap(rawConfig, "definednet", "dns"); len(stringList(dns, "resolver_addrs")) > 0 {
		result.Source = "managed"
		result.Resolvers = stringList(dns, "resolver_addrs")
		result.MatchDomains = stringList(dns, "match_domains")
		result.SearchDomains = stringList(dns, "search_domains")
	} else if mn := getMap(rawConfig, "mobile_nebula"); mn != nil {
		result.Resolvers = stringList(mn, "dns_resolvers")
		result.MatchDomains = stringList(mn, "match_domains")
		result.SearchDomains = stringList(mn, "search_domains")
	}

	// Marshal empty lists as [] rather than null for the platform parsers
	if result.Resolvers == nil {
		result.Resolvers = []string{}
	}
	if result.MatchDomains == nil {
		result.MatchDomains = []string{}
	}
	if result.SearchDomains == nil {
		result.SearchDomains = []string{}
	}

	out, err := json.Marshal(result)
	if err != nil {
		return "", err
	}
	return string(out), nil
}

// getMap walks nested map keys, returning nil if any step is missing or not a map.
func getMap(m map[string]any, path ...string) map[string]any {
	cur := m
	for _, k := range path {
		next, ok := cur[k].(map[string]any)
		if !ok {
			return nil
		}
		cur = next
	}
	return cur
}

// stringList reads a list of strings at key, dropping non-string and empty entries.
func stringList(m map[string]any, key string) []string {
	if m == nil {
		return nil
	}
	raw, ok := m[key].([]any)
	if !ok {
		return nil
	}
	out := make([]string, 0, len(raw))
	for _, v := range raw {
		if s, ok := v.(string); ok && s != "" {
			out = append(out, s)
		}
	}
	if len(out) == 0 {
		return nil
	}
	return out
}
