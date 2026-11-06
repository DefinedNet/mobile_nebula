package mobileNebula

import (
	"encoding/json"
	"fmt"
	"log/slog"

	nc "github.com/slackhq/nebula/config"
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
// else the managed DNS settings in rawConfig (see managedDNS). Returns a JSON
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

	managed, hasManaged := managedDNS(loadRawConfig(s.RawConfig))

	result := effectiveDNS{Source: "none"}

	if s.DNSOverride != nil && s.DNSOverride.Enabled {
		// Enabled with empty resolvers deliberately disables DNS on this device.
		result.Source = "override"
		result.Resolvers = s.DNSOverride.Resolvers
		result.MatchDomains = s.DNSOverride.MatchDomains
		result.SearchDomains = s.DNSOverride.SearchDomains
	} else if hasManaged {
		result.Source = "managed"
		result.Resolvers = managed.Resolvers
		result.MatchDomains = managed.MatchDomains
		result.SearchDomains = managed.SearchDomains
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

// managedDNS reads the managed DNS settings out of a site's nebula config.
// Nebula's own top-level dns stanza is authoritative whenever the key is
// present, null included, because that is how nebula reads it: an admin who
// turned it off should not find this device still installing resolvers from
// the older definednet.dns block, which is read only when there is no dns key
// at all. ok is false when the config installs no DNS.
func managedDNS(c *nc.C) (effectiveDNS, bool) {
	if _, present := c.Settings["dns"]; present {
		return nebulaDNS(c)
	}
	return definedNetDNS(c.GetMap("definednet.dns", nil))
}

// loadRawConfig reads a site's rawConfig, which is JSON and therefore YAML,
// into nebula's config type so that the dns stanza can be read with nebula's
// own getters. An unparsable rawConfig loads as empty: the site loaders report
// the parse failure, and a usable override should not be lost alongside it.
func loadRawConfig(raw string) *nc.C {
	c := nc.NewC(slog.New(slog.DiscardHandler))
	_ = c.LoadString(raw)
	return c
}

// nebulaDNS extracts the DNS settings nebula's dns stanza asks for, the way
// loadHostDNSConfig reads them. It does not validate: the site loaders run
// nebula's own config test over the same config, and the embedded nebula
// refuses to start on a stanza it cannot load. A stanza nebula refuses, or a
// key that cannot be read as a list, installs nothing here.
//
// Nebula's rules for the domain lists are reproduced because the platform
// needs their result: match_domains defaults to search_domains when unset, an
// empty match_domains is catch-all, and a stanza that sets neither list is
// refused rather than treated as catch-all.
func nebulaDNS(c *nc.C) (effectiveDNS, bool) {
	if !c.GetBool("dns.enabled", false) {
		return effectiveDNS{}, false
	}

	nameservers, err := c.GetStringSliceStrict("dns.nameservers")
	if err != nil || len(nameservers) == 0 {
		return effectiveDNS{}, false
	}

	search, err := c.GetStringSliceStrict("dns.search_domains")
	if err != nil {
		return effectiveDNS{}, false
	}
	match := search
	if c.IsSet("dns.match_domains") {
		if match, err = c.GetStringSliceStrict("dns.match_domains"); err != nil {
			return effectiveDNS{}, false
		}
	} else if len(search) == 0 {
		return effectiveDNS{}, false
	}

	return effectiveDNS{Resolvers: nameservers, MatchDomains: match, SearchDomains: search}, true
}

// definedNetDNS reads the older definednet.dns block. Non-empty resolver_addrs
// is the install signal, matching dnclient.
func definedNetDNS(dns map[string]any) (effectiveDNS, bool) {
	resolvers := stringList(dns, "resolver_addrs")
	if len(resolvers) == 0 {
		return effectiveDNS{}, false
	}
	return effectiveDNS{
		Resolvers:     resolvers,
		MatchDomains:  stringList(dns, "match_domains"),
		SearchDomains: stringList(dns, "search_domains"),
	}, true
}

// orEmpty replaces a nil list with an empty one.
func orEmpty(l []string) []string {
	if l == nil {
		return []string{}
	}
	return l
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
