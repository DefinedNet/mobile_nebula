package mobileNebula

import (
	"encoding/json"
	"maps"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
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
