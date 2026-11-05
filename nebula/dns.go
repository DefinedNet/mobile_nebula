package mobileNebula

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"slices"

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
//
// A dns stanza that cannot be read is an error whether or not an override is
// in effect, since the override cannot rescue a config nebula will not run.
func EffectiveDNS(siteJSON string) (string, error) {
	var s struct {
		RawConfig   string       `json:"rawConfig"`
		DNSOverride *dnsOverride `json:"dnsOverride"`
	}
	if err := json.Unmarshal([]byte(siteJSON), &s); err != nil {
		return "", fmt.Errorf("failed to parse site JSON: %s", err)
	}

	managed, hasManaged, err := managedDNS(loadRawConfig(s.RawConfig))
	if err != nil {
		return "", err
	}

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
// Nebula's own top-level dns stanza is authoritative whenever it is present:
// it is the setting nebula itself honours, and an admin who turned it off
// should not find this device still installing resolvers from the older
// definednet.dns block. That block is read only when there is no dns key at
// all; a dns key of any shape is the stanza, as it is to nebula, which reads a
// scalar there as a disabled stanza. ok is false when the config installs no
// DNS, and err is set when the dns stanza cannot be read.
func managedDNS(c *nc.C) (dns effectiveDNS, ok bool, err error) {
	if c.IsSet("dns") {
		return nebulaDNS(c)
	}
	dns, ok = definedNetDNS(c.GetMap("definednet.dns", nil))
	return dns, ok, nil
}

// loadRawConfig reads a site's rawConfig into nebula's config type so the dns
// stanza can be read with the getters nebula itself uses. rawConfig is JSON,
// which the YAML parser accepts. An unparsable rawConfig holds no readable
// managed DNS and loads as empty, and the site loaders already surface the
// parse failure. Resolving to no DNS keeps a usable override from being
// discarded alongside it, matching the tolerance MigrateConfigV2 has for the
// same input.
func loadRawConfig(raw string) *nc.C {
	c := nc.NewC(slog.New(slog.DiscardHandler))
	_ = c.LoadString(raw)
	return c
}

// nebulaDNS reads the DNS settings nebula's dns stanza asks for, the way
// loadHostDNSConfig reads them. It extracts and does not validate: the site
// loaders run TestConfig, nebula's own config test, over the same config, and
// the nebula embedded in this app refuses to start on a stanza it cannot
// load, so a bad stanza is reported there. Only the shape has to hold up
// here, because a key that is not a list cannot be read at all.
//
// Two rules of nebula's are reproduced because the platform needs their
// result: match_domains defaults to search_domains when unset, and an
// explicitly empty match_domains is the opt in to catching every query. A
// stanza that sets neither list is one nebula refuses rather than treats as
// catch-all, and it installs nothing here. The stanza is inert unless enabled
// with at least one nameserver and a domain list.
func nebulaDNS(c *nc.C) (effectiveDNS, bool, error) {
	if !c.GetBool("dns.enabled", false) {
		return effectiveDNS{}, false, nil
	}

	nameservers, err := c.GetStringSliceStrict("dns.nameservers")
	if err != nil {
		return effectiveDNS{}, false, err
	}
	if len(nameservers) == 0 {
		return effectiveDNS{}, false, nil
	}

	search, err := c.GetStringSliceStrict("dns.search_domains")
	if err != nil {
		return effectiveDNS{}, false, err
	}
	var match []string
	switch {
	case c.IsSet("dns.match_domains"):
		if match, err = c.GetStringSliceStrict("dns.match_domains"); err != nil {
			return effectiveDNS{}, false, err
		}
	case len(search) == 0:
		return effectiveDNS{}, false, nil
	default:
		match = slices.Clone(search)
	}

	return effectiveDNS{Resolvers: nameservers, MatchDomains: match, SearchDomains: search}, true, nil
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
