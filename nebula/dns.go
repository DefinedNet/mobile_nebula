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
	// Source records which channel won: "override", "managed", or "none".
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
// resolver_addrs is the install signal, matching dnclient). Returns a JSON
// object:
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

	result := effectiveDNS{Source: "none"}

	if s.DNSOverride != nil && s.DNSOverride.Enabled {
		// Enabled with empty resolvers deliberately disables DNS on this device.
		result.Source = "override"
		result.Resolvers = s.DNSOverride.Resolvers
		result.MatchDomains = s.DNSOverride.MatchDomains
		result.SearchDomains = s.DNSOverride.SearchDomains
	} else {
		// An unparsable rawConfig holds no readable managed DNS, and the site
		// loaders already surface the parse failure. Resolving to no DNS keeps a
		// usable override from being discarded alongside it, matching the
		// tolerance MigrateConfigV2 has for the same input.
		var rawConfig map[string]any
		_ = json.Unmarshal([]byte(s.RawConfig), &rawConfig)

		dns := getMap(rawConfig, "definednet", "dns")
		if resolvers := stringList(dns, "resolver_addrs"); len(resolvers) > 0 {
			result.Source = "managed"
			result.Resolvers = resolvers
			result.MatchDomains = stringList(dns, "match_domains")
			result.SearchDomains = stringList(dns, "search_domains")
		}
	}

	// Marshal empty lists as [] rather than null for the platform parsers
	result.Resolvers = orEmpty(result.Resolvers)
	result.MatchDomains = orEmpty(result.MatchDomains)
	result.SearchDomains = orEmpty(result.SearchDomains)

	out, err := json.Marshal(result)
	if err != nil {
		return "", err
	}
	return string(out), nil
}

// orEmpty replaces a nil list with an empty one.
func orEmpty(l []string) []string {
	if l == nil {
		return []string{}
	}
	return l
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
