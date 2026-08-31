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

func TestEffectiveDNS_ManagedWinsOverManual(t *testing.T) {
	s := siteJSON(t, map[string]any{
		"definednet": map[string]any{
			"dns": map[string]any{
				"resolver_addrs": []string{"240.0.0.1"},
			},
		},
		"mobile_nebula": map[string]any{
			"dns_resolvers": []string{"1.1.1.1"},
		},
	}, nil)

	result := effectiveDNSFromJSON(t, s)
	assert.Equal(t, "managed", result.Source)
	assert.Equal(t, []string{"240.0.0.1"}, result.Resolvers)
}

func TestEffectiveDNS_EmptyManagedFallsBackToManual(t *testing.T) {
	// resolver_addrs is the install signal; empty means the managed channel is inert
	s := siteJSON(t, map[string]any{
		"definednet": map[string]any{
			"dns": map[string]any{
				"resolver_addrs": []string{},
				"match_domains":  []string{"ignored.example.com"},
			},
		},
		"mobile_nebula": map[string]any{
			"dns_resolvers": []string{"1.1.1.1"},
			"match_domains": []string{"internal.example.com"},
		},
	}, nil)

	result := effectiveDNSFromJSON(t, s)
	assert.Equal(t, "manual", result.Source)
	assert.Equal(t, []string{"1.1.1.1"}, result.Resolvers)
	assert.Equal(t, []string{"internal.example.com"}, result.MatchDomains)
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
	assert.Equal(t, "manual", result.Source)
	assert.Empty(t, result.Resolvers)
	assert.Empty(t, result.MatchDomains)
	assert.Empty(t, result.SearchDomains)
}

func TestEffectiveDNS_EmptyListsMarshalAsArrays(t *testing.T) {
	out, err := EffectiveDNS(`{"rawConfig": "{}"}`)
	require.NoError(t, err)
	assert.JSONEq(t, `{"resolvers": [], "matchDomains": [], "searchDomains": [], "source": "manual"}`, out)
}

func TestEffectiveDNS_MissingRawConfig(t *testing.T) {
	result := effectiveDNSFromJSON(t, `{}`)
	assert.Equal(t, "manual", result.Source)
	assert.Empty(t, result.Resolvers)
}

func TestEffectiveDNS_InvalidJSON(t *testing.T) {
	_, err := EffectiveDNS(`not json`)
	assert.Error(t, err)

	_, err = EffectiveDNS(`{"rawConfig": "not json"}`)
	assert.Error(t, err)
}
