package mobileNebula

import (
	"encoding/json"
	"fmt"
	"maps"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"gopkg.in/yaml.v2"
)

func effectiveDNSFromJSON(t *testing.T, siteJSON string) effectiveDNS {
	t.Helper()
	out, err := EffectiveDNS(siteJSON)
	require.NoError(t, err)
	var result effectiveDNS
	require.NoError(t, json.Unmarshal([]byte(out), &result))
	return result
}

func siteJSON(t *testing.T, rawConfig map[string]any, extra map[string]any) string {
	t.Helper()
	rawBytes, err := json.Marshal(rawConfig)
	require.NoError(t, err)
	site := map[string]any{"rawConfig": string(rawBytes)}
	maps.Copy(site, extra)
	siteBytes, err := json.Marshal(site)
	require.NoError(t, err)
	return string(siteBytes)
}

func TestEffectiveDNS_Managed(t *testing.T) {
	s := siteJSON(t, map[string]any{
		"definednet": map[string]any{
			"dns": map[string]any{
				"resolver_addrs": []string{"240.0.0.1", "240.0.0.2"},
				"match_domains":  []string{"internal.example.com"},
				"search_domains": []string{"example.com"},
			},
		},
	}, nil)

	result := effectiveDNSFromJSON(t, s)
	assert.Equal(t, "managed", result.Source)
	assert.Equal(t, []string{"240.0.0.1", "240.0.0.2"}, result.Resolvers)
	assert.Equal(t, []string{"internal.example.com"}, result.MatchDomains)
	assert.Equal(t, []string{"example.com"}, result.SearchDomains)
}

func TestEffectiveDNS_EmptyManagedIsInert(t *testing.T) {
	// resolver_addrs is the install signal; empty means the managed channel is inert
	s := siteJSON(t, map[string]any{
		"definednet": map[string]any{
			"dns": map[string]any{
				"resolver_addrs": []string{},
				"match_domains":  []string{"ignored.example.com"},
			},
		},
	}, nil)

	result := effectiveDNSFromJSON(t, s)
	assert.Equal(t, "none", result.Source)
	assert.Empty(t, result.Resolvers)
	assert.Empty(t, result.MatchDomains)
}

func TestEffectiveDNS_NebulaStanza(t *testing.T) {
	s := siteJSON(t, map[string]any{
		"dns": map[string]any{
			"enabled":        true,
			"nameservers":    []string{"240.0.0.1", "240.0.0.2"},
			"match_domains":  []string{"example.com"},
			"search_domains": []string{"internal.example.com"},
		},
	}, nil)

	result := effectiveDNSFromJSON(t, s)
	assert.Equal(t, "managed", result.Source)
	assert.Equal(t, []string{"240.0.0.1", "240.0.0.2"}, result.Resolvers)
	assert.Equal(t, []string{"example.com"}, result.MatchDomains)
	assert.Equal(t, []string{"internal.example.com"}, result.SearchDomains)
}

func TestEffectiveDNS_NebulaStanzaWinsOverDefinedNet(t *testing.T) {
	s := siteJSON(t, map[string]any{
		"dns": map[string]any{
			"enabled":       true,
			"nameservers":   []string{"240.0.0.1"},
			"match_domains": []string{"new.example.com"},
		},
		"definednet": map[string]any{
			"dns": map[string]any{
				"resolver_addrs": []string{"10.9.9.9"},
				"match_domains":  []string{"old.example.com"},
			},
		},
	}, nil)

	result := effectiveDNSFromJSON(t, s)
	assert.Equal(t, "managed", result.Source)
	assert.Equal(t, []string{"240.0.0.1"}, result.Resolvers)
	assert.Equal(t, []string{"new.example.com"}, result.MatchDomains)
}

func TestEffectiveDNS_NebulaStanzaDisabledSuppressesDefinedNet(t *testing.T) {
	// A dns stanza that is present owns the managed channel even when it is
	// off; definednet.dns is only a fallback for configs without one
	for _, enabled := range []any{false, "false", "no", nil} {
		t.Run(fmt.Sprintf("enabled=%#v", enabled), func(t *testing.T) {
			dns := map[string]any{"nameservers": []string{"240.0.0.1"}, "match_domains": []string{"example.com"}}
			if enabled != nil {
				dns["enabled"] = enabled
			}
			s := siteJSON(t, map[string]any{
				"dns": dns,
				"definednet": map[string]any{
					"dns": map[string]any{"resolver_addrs": []string{"10.9.9.9"}},
				},
			}, nil)

			result := effectiveDNSFromJSON(t, s)
			assert.Equal(t, "none", result.Source)
			assert.Empty(t, result.Resolvers)
		})
	}
}

func TestEffectiveDNS_NebulaStanzaEnabledAsString(t *testing.T) {
	s := siteJSON(t, map[string]any{
		"dns": map[string]any{
			"enabled":       "yes",
			"nameservers":   []string{"240.0.0.1"},
			"match_domains": []string{"example.com"},
		},
	}, nil)

	result := effectiveDNSFromJSON(t, s)
	assert.Equal(t, "managed", result.Source)
	assert.Equal(t, []string{"240.0.0.1"}, result.Resolvers)
}

func TestEffectiveDNS_NebulaStanzaMatchDefaultsToSearch(t *testing.T) {
	s := siteJSON(t, map[string]any{
		"dns": map[string]any{
			"enabled":        true,
			"nameservers":    []string{"240.0.0.1"},
			"search_domains": []string{"example.com"},
		},
	}, nil)

	result := effectiveDNSFromJSON(t, s)
	assert.Equal(t, "managed", result.Source)
	assert.Equal(t, []string{"example.com"}, result.MatchDomains)
	assert.Equal(t, []string{"example.com"}, result.SearchDomains)
}

func TestEffectiveDNS_NebulaStanzaEmptyMatchIsCatchAll(t *testing.T) {
	s := siteJSON(t, map[string]any{
		"dns": map[string]any{
			"enabled":        true,
			"nameservers":    []string{"240.0.0.1"},
			"match_domains":  []string{},
			"search_domains": []string{"example.com"},
		},
	}, nil)

	result := effectiveDNSFromJSON(t, s)
	assert.Equal(t, "managed", result.Source)
	assert.Equal(t, []string{"240.0.0.1"}, result.Resolvers)
	assert.Empty(t, result.MatchDomains)
	assert.Equal(t, []string{"example.com"}, result.SearchDomains)
}

func TestEffectiveDNS_NebulaStanzaNoNameserversIsInert(t *testing.T) {
	// Nebula refuses to start on this stanza, which TestConfig reports; here
	// there is simply nothing to install
	s := siteJSON(t, map[string]any{
		"dns": map[string]any{
			"enabled":       true,
			"nameservers":   []string{},
			"match_domains": []string{"example.com"},
		},
	}, nil)

	result := effectiveDNSFromJSON(t, s)
	assert.Equal(t, "none", result.Source)
	assert.Empty(t, result.Resolvers)
}

func TestEffectiveDNS_NebulaStanzaNoDomainsIsInert(t *testing.T) {
	// Nebula refuses this stanza rather than catching every query, which
	// TestConfig reports; the platform must not install catch-all DNS for it
	for name, dns := range map[string]map[string]any{
		"neither key":       {"enabled": true, "nameservers": []string{"240.0.0.1"}},
		"empty search only": {"enabled": true, "nameservers": []string{"240.0.0.1"}, "search_domains": []string{}},
	} {
		t.Run(name, func(t *testing.T) {
			result := effectiveDNSFromJSON(t, siteJSON(t, map[string]any{"dns": dns}, nil))
			assert.Equal(t, "none", result.Source)
			assert.Empty(t, result.Resolvers)
			assert.Empty(t, result.MatchDomains)
		})
	}
}

func TestEffectiveDNS_NebulaStanzaScalarSuppressesDefinedNet(t *testing.T) {
	// Nebula reads a scalar dns key as a disabled stanza, and so does mobile:
	// it must not fall back to the legacy block
	s := siteJSON(t, map[string]any{
		"dns": false,
		"definednet": map[string]any{
			"dns": map[string]any{
				"resolver_addrs": []string{"240.0.0.1"},
				"match_domains":  []string{"example.com"},
			},
		},
	}, nil)

	result := effectiveDNSFromJSON(t, s)
	assert.Equal(t, "none", result.Source)
	assert.Empty(t, result.Resolvers)
}

func TestEffectiveDNS_NebulaStanzaDisabledIgnoresResolverKeys(t *testing.T) {
	// Nebula only loads the resolver keys when the stanza is enabled
	s := siteJSON(t, map[string]any{
		"dns": map[string]any{
			"enabled":     false,
			"nameservers": "garbage",
		},
	}, nil)
	result := effectiveDNSFromJSON(t, s)
	assert.Equal(t, "none", result.Source)
}

func TestEffectiveDNS_NebulaStanzaUnreadableKeys(t *testing.T) {
	// A key that is not a list cannot be read, with or without an override
	for _, key := range []string{"nameservers", "search_domains", "match_domains"} {
		t.Run(key, func(t *testing.T) {
			dns := map[string]any{
				"enabled":        true,
				"nameservers":    []string{"240.0.0.1"},
				"search_domains": []string{"example.com"},
			}
			dns[key] = "not a list"
			s := siteJSON(t, map[string]any{"dns": dns}, map[string]any{
				"dnsOverride": map[string]any{"enabled": true, "resolvers": []string{"192.168.1.53"}},
			})

			_, err := EffectiveDNS(s)
			require.Error(t, err)
			assert.Contains(t, err.Error(), "dns."+key+" must be a list")
		})
	}
}

func TestEffectiveDNS_NebulaStanzaPassesNameserversThrough(t *testing.T) {
	// Validation is nebula's job, the platform gets the entries as written
	s := siteJSON(t, map[string]any{
		"dns": map[string]any{
			"enabled":       true,
			"nameservers":   []string{"FD00::1", "240.0.0.1"},
			"match_domains": []string{"example.com"},
		},
	}, nil)

	result := effectiveDNSFromJSON(t, s)
	assert.Equal(t, []string{"FD00::1", "240.0.0.1"}, result.Resolvers)
}

func TestTestConfig_RefusesBadNebulaDNS(t *testing.T) {
	// Validation of the stanza is left to nebula, which the site loaders run
	// through TestConfig. Each stanza here is one nebula refuses to start on,
	// and the error names the same key nebula does.
	base := func(overrides map[string]any) map[string]any {
		dns := map[string]any{
			"enabled":       true,
			"nameservers":   []any{"240.0.0.1"},
			"match_domains": []any{"example.com"},
		}
		maps.Copy(dns, overrides)
		return map[string]any{"dns": dns}
	}
	cases := []struct {
		name      string
		rawConfig map[string]any
		want      []string
	}{
		{"no nameservers", base(map[string]any{"nameservers": []any{}}), []string{"dns.nameservers must have at least one entry"}},
		{"no domains", base(map[string]any{"match_domains": nil}), []string{"dns requires search_domains or match_domains"}},
		{"nameserver not an IP", base(map[string]any{"nameservers": []any{"240.0.0.1", "dns.example.com"}}), []string{`ParseAddr("dns.example.com")`}},
		{"nameservers not a list", base(map[string]any{"nameservers": "240.0.0.1"}), []string{"dns.nameservers must be a list"}},
		{"unspecified nameserver", base(map[string]any{"nameservers": []any{"0.0.0.0"}}), []string{"0.0.0.0", "cannot serve DNS"}},
		{"empty match entry", base(map[string]any{"match_domains": []any{"example.com", ""}}), []string{"entry 2 in dns.match_domains is empty"}},
		{"root match domain", base(map[string]any{"match_domains": []any{"."}}), []string{"entry 1 in dns.match_domains is the root domain"}},
		{"empty search entry", base(map[string]any{"search_domains": []any{""}}), []string{"entry 1 in dns.search_domains is empty"}},
		{"search not under match", base(map[string]any{"search_domains": []any{"other.example.net"}}), []string{"is not under any MatchDomains entry"}},
		{"duplicate match domain", base(map[string]any{"match_domains": []any{"example.com", "EXAMPLE.COM."}}), []string{"duplicates"}},
		{"bad identity", base(map[string]any{"identity": "Nebula Mobile"}), []string{"dns.identity is not usable"}},
		{"bad identity while disabled", base(map[string]any{"enabled": false, "identity": "Not Valid"}), []string{"dns.identity is not usable"}},
		{"tun disabled", func() map[string]any {
			rc := base(nil)
			rc["tun"] = map[string]any{"disabled": true}
			return rc
		}(), []string{"dns.enabled requires a tun device, but tun.disabled is true"}},
		{"every problem reported", base(map[string]any{"nameservers": []any{"not-an-ip"}, "match_domains": nil, "search_domains": []any{""}}),
			[]string{"not an IP address", "entry 1 in dns.search_domains is empty"}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			err := TestConfig(siteJSON(t, tc.rawConfig, nil), "")
			require.Error(t, err)
			for _, want := range tc.want {
				assert.Contains(t, err.Error(), want)
			}
		})
	}
}

func TestEffectiveDNS_OverrideWinsOverNebulaStanza(t *testing.T) {
	s := siteJSON(t, map[string]any{
		"dns": map[string]any{
			"enabled":       true,
			"nameservers":   []string{"240.0.0.1"},
			"match_domains": []string{"example.com"},
		},
	}, map[string]any{
		"dnsOverride": map[string]any{
			"enabled":   true,
			"resolvers": []string{"192.168.1.53"},
		},
	})

	result := effectiveDNSFromJSON(t, s)
	assert.Equal(t, "override", result.Source)
	assert.Equal(t, []string{"192.168.1.53"}, result.Resolvers)
}

func TestEffectiveDNS_MobileNebulaIgnored(t *testing.T) {
	// mobile_nebula DNS settings only exist in pre-v2 configs; MigrateConfigV2
	// hoists them into dnsOverride and the resolver no longer reads them
	s := siteJSON(t, map[string]any{
		"mobile_nebula": map[string]any{
			"dns_resolvers": []string{"1.1.1.1"},
			"match_domains": []string{"internal.example.com"},
		},
	}, nil)

	result := effectiveDNSFromJSON(t, s)
	assert.Equal(t, "none", result.Source)
	assert.Empty(t, result.Resolvers)
	assert.Empty(t, result.MatchDomains)
}

func TestEffectiveDNS_OverrideWinsOverManaged(t *testing.T) {
	s := siteJSON(t, map[string]any{
		"definednet": map[string]any{
			"dns": map[string]any{
				"resolver_addrs": []string{"240.0.0.1"},
			},
		},
	}, map[string]any{
		"dnsOverride": map[string]any{
			"enabled":       true,
			"resolvers":     []string{"192.168.1.53"},
			"searchDomains": []string{"home.example.com"},
		},
	})

	result := effectiveDNSFromJSON(t, s)
	assert.Equal(t, "override", result.Source)
	assert.Equal(t, []string{"192.168.1.53"}, result.Resolvers)
	assert.Equal(t, []string{"home.example.com"}, result.SearchDomains)
}

func TestEffectiveDNS_OverrideEnabledEmptyDisablesDNS(t *testing.T) {
	s := siteJSON(t, map[string]any{
		"definednet": map[string]any{
			"dns": map[string]any{
				"resolver_addrs": []string{"240.0.0.1"},
			},
		},
	}, map[string]any{
		"dnsOverride": map[string]any{
			"enabled":   true,
			"resolvers": []string{},
		},
	})

	result := effectiveDNSFromJSON(t, s)
	assert.Equal(t, "override", result.Source)
	assert.Empty(t, result.Resolvers)
}

func TestEffectiveDNS_DisabledOverrideIsIgnored(t *testing.T) {
	s := siteJSON(t, map[string]any{
		"definednet": map[string]any{
			"dns": map[string]any{
				"resolver_addrs": []string{"240.0.0.1"},
			},
		},
	}, map[string]any{
		"dnsOverride": map[string]any{
			"enabled":   false,
			"resolvers": []string{"192.168.1.53"},
		},
	})

	result := effectiveDNSFromJSON(t, s)
	assert.Equal(t, "managed", result.Source)
	assert.Equal(t, []string{"240.0.0.1"}, result.Resolvers)
}

func TestEffectiveDNS_NoDNSAnywhere(t *testing.T) {
	s := siteJSON(t, map[string]any{}, nil)

	result := effectiveDNSFromJSON(t, s)
	assert.Equal(t, "none", result.Source)
	assert.Empty(t, result.Resolvers)
	assert.Empty(t, result.MatchDomains)
	assert.Empty(t, result.SearchDomains)
}

func TestEffectiveDNS_EmptyListsMarshalAsArrays(t *testing.T) {
	out, err := EffectiveDNS(`{"rawConfig": "{}"}`)
	require.NoError(t, err)
	assert.JSONEq(t, `{"resolvers": [], "matchDomains": [], "searchDomains": [], "source": "none"}`, out)
}

func TestEffectiveDNS_MissingRawConfig(t *testing.T) {
	result := effectiveDNSFromJSON(t, `{}`)
	assert.Equal(t, "none", result.Source)
	assert.Empty(t, result.Resolvers)
}

func TestEffectiveDNS_InvalidJSON(t *testing.T) {
	_, err := EffectiveDNS(`not json`)
	assert.Error(t, err)
}

func TestEffectiveDNS_UnparsableRawConfigYieldsNoManagedDNS(t *testing.T) {
	result := effectiveDNSFromJSON(t, `{"rawConfig": "not json"}`)
	assert.Equal(t, "none", result.Source)
	assert.Empty(t, result.Resolvers)
}

func TestEffectiveDNS_UnparsableRawConfigKeepsOverride(t *testing.T) {
	// The site loaders report the rawConfig parse failure on their own; losing
	// the override here would report it twice and throw away usable settings
	result := effectiveDNSFromJSON(t, `{"rawConfig": "not json", "dnsOverride": {"enabled": true, "resolvers": ["10.1.1.1"]}}`)
	assert.Equal(t, "override", result.Source)
	assert.Equal(t, []string{"10.1.1.1"}, result.Resolvers)
}

func migrateV2(t *testing.T, siteJSON string) map[string]any {
	t.Helper()
	out, err := MigrateConfigV2(siteJSON)
	require.NoError(t, err)
	var siteMap map[string]any
	require.NoError(t, json.Unmarshal([]byte(out), &siteMap))
	return siteMap
}

func rawConfigOf(t *testing.T, siteMap map[string]any) map[string]any {
	t.Helper()
	rc, ok := siteMap["rawConfig"].(string)
	require.True(t, ok)
	var rawConfig map[string]any
	require.NoError(t, json.Unmarshal([]byte(rc), &rawConfig))
	return rawConfig
}

func TestMigrateConfigV2_MovesDNSToOverride(t *testing.T) {
	s := siteJSON(t, map[string]any{
		"mobile_nebula": map[string]any{
			"dns_resolvers":  []string{"1.1.1.1"},
			"match_domains":  []string{"internal.example.com"},
			"search_domains": []string{"example.com"},
		},
	}, map[string]any{"configVersion": 1})

	siteMap := migrateV2(t, s)
	assert.Equal(t, float64(2), siteMap["configVersion"])
	assert.Equal(t, map[string]any{
		"enabled":       true,
		"resolvers":     []any{"1.1.1.1"},
		"matchDomains":  []any{"internal.example.com"},
		"searchDomains": []any{"example.com"},
	}, siteMap["dnsOverride"])

	// The now-empty mobile_nebula block is removed entirely
	rawConfig := rawConfigOf(t, siteMap)
	assert.NotContains(t, rawConfig, "mobile_nebula")

	// The migrated site resolves to the override
	out, err := json.Marshal(siteMap)
	require.NoError(t, err)
	result := effectiveDNSFromJSON(t, string(out))
	assert.Equal(t, "override", result.Source)
	assert.Equal(t, []string{"1.1.1.1"}, result.Resolvers)
}

func TestMigrateConfigV2_KeepsOtherMobileNebulaKeys(t *testing.T) {
	s := siteJSON(t, map[string]any{
		"mobile_nebula": map[string]any{
			"dns_resolvers": []string{"1.1.1.1"},
			"future_knob":   "keep",
		},
	}, nil)

	siteMap := migrateV2(t, s)
	rawConfig := rawConfigOf(t, siteMap)
	assert.Equal(t, map[string]any{"future_knob": "keep"}, rawConfig["mobile_nebula"])
}

func TestMigrateConfigV2_NoDNSSettings(t *testing.T) {
	s := siteJSON(t, map[string]any{
		"tun": map[string]any{"mtu": 1300},
	}, nil)

	siteMap := migrateV2(t, s)
	assert.Equal(t, float64(2), siteMap["configVersion"])
	assert.NotContains(t, siteMap, "dnsOverride")
	assert.Equal(t, map[string]any{"mtu": float64(1300)}, rawConfigOf(t, siteMap)["tun"])
}

func TestMigrateConfigV2_ExistingOverridePreserved(t *testing.T) {
	s := siteJSON(t, map[string]any{
		"mobile_nebula": map[string]any{
			"dns_resolvers": []string{"1.1.1.1"},
		},
	}, map[string]any{
		"dnsOverride": map[string]any{
			"enabled":   true,
			"resolvers": []any{"192.168.1.53"},
		},
	})

	siteMap := migrateV2(t, s)
	override, ok := siteMap["dnsOverride"].(map[string]any)
	require.True(t, ok)
	assert.Equal(t, []any{"192.168.1.53"}, override["resolvers"])
	assert.NotContains(t, rawConfigOf(t, siteMap), "mobile_nebula")
}

func TestMigrateConfigV2_MissingRawConfig(t *testing.T) {
	siteMap := migrateV2(t, `{"name": "test"}`)
	assert.Equal(t, float64(2), siteMap["configVersion"])
	assert.Equal(t, "test", siteMap["name"])
}

func TestMigrateConfigV2_InvalidJSON(t *testing.T) {
	_, err := MigrateConfigV2(`not json`)
	assert.Error(t, err)
}

func TestMigrateConfigV2_UnparsableRawConfigStillMigrates(t *testing.T) {
	// A migration error gets the site deleted as non-conforming by the platform
	// loaders; an unparsable rawConfig must instead pass through untouched so
	// the site loads and surfaces a parse error
	siteMap := migrateV2(t, `{"rawConfig": "not json"}`)
	assert.Equal(t, float64(2), siteMap["configVersion"])
	assert.Equal(t, "not json", siteMap["rawConfig"])
}

func TestMigrateConfigV2_NullOverrideStillHoists(t *testing.T) {
	s := siteJSON(t, map[string]any{
		"mobile_nebula": map[string]any{
			"dns_resolvers": []string{"1.1.1.1"},
		},
	}, map[string]any{"dnsOverride": nil})

	siteMap := migrateV2(t, s)
	override, ok := siteMap["dnsOverride"].(map[string]any)
	require.True(t, ok)
	assert.Equal(t, []any{"1.1.1.1"}, override["resolvers"])
	assert.NotContains(t, rawConfigOf(t, siteMap), "mobile_nebula")
}

// apiRenderedSite builds a site whose rawConfig came through the path a managed
// config takes: the DN API merges overrides into a map with bare Go values and
// marshals it with yaml.v2 (api/internal/app/nebula_config.go), and the mobile
// client converts that YAML to the JSON rawConfig with yamlToJSONMap.
func apiRenderedSite(t *testing.T, cfg map[string]any) string {
	t.Helper()
	yamlBytes, err := yaml.Marshal(cfg)
	require.NoError(t, err)
	rawConfig, err := yamlToJSONMap(yamlBytes)
	require.NoError(t, err)
	return siteJSON(t, rawConfig, nil)
}

func TestEffectiveDNS_NebulaStanzaFromAPIRenderedConfig(t *testing.T) {
	// The override set from the DN API's config-overrides e2e test, which
	// carries both the legacy block and the nebula stanza
	s := apiRenderedSite(t, map[string]any{
		"definednet": map[string]any{
			"dns": map[string]any{
				"resolver_addrs": []string{"240.0.0.1"},
				"match_domains":  []string{"match.internal"},
				"search_domains": []string{"search.internal"},
			},
		},
		"dns": map[string]any{
			"enabled":        true,
			"nameservers":    []string{"192.168.100.1"},
			"match_domains":  []string{"mesh.internal"},
			"search_domains": []string{"mesh.internal"},
		},
	})

	result := effectiveDNSFromJSON(t, s)
	assert.Equal(t, "managed", result.Source)
	assert.Equal(t, []string{"192.168.100.1"}, result.Resolvers)
	assert.Equal(t, []string{"mesh.internal"}, result.MatchDomains)
	assert.Equal(t, []string{"mesh.internal"}, result.SearchDomains)
}

func TestEffectiveDNS_NebulaStanzaFromAPIRenderedCatchAll(t *testing.T) {
	// The API accepts an empty dns.match_domains override; it must survive the
	// YAML round trip as a set-but-empty list, which is the catch-all opt in
	s := apiRenderedSite(t, map[string]any{
		"dns": map[string]any{
			"enabled":        true,
			"nameservers":    []string{"fd00::1", "240.0.0.1"},
			"match_domains":  []string{},
			"search_domains": []string{"mesh.internal"},
		},
	})

	result := effectiveDNSFromJSON(t, s)
	assert.Equal(t, "managed", result.Source)
	assert.Equal(t, []string{"fd00::1", "240.0.0.1"}, result.Resolvers)
	assert.Empty(t, result.MatchDomains)
	assert.Equal(t, []string{"mesh.internal"}, result.SearchDomains)
}

func TestEffectiveDNS_NebulaStanzaFromAPIRenderedDisabled(t *testing.T) {
	// dns.enabled false alongside the legacy block: the stanza owns the
	// managed channel, which means mobile installs nothing
	s := apiRenderedSite(t, map[string]any{
		"definednet": map[string]any{
			"dns": map[string]any{"resolver_addrs": []string{"240.0.0.1"}},
		},
		"dns": map[string]any{
			"enabled":     false,
			"nameservers": []string{"192.168.100.1"},
		},
	})

	result := effectiveDNSFromJSON(t, s)
	assert.Equal(t, "none", result.Source)
	assert.Empty(t, result.Resolvers)
}
