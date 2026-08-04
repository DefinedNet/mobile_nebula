package mobileNebula

import (
	"encoding/json"
	"log/slog"
	"strconv"
	"testing"

	nebcfg "github.com/slackhq/nebula/config"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestRenderConfig(t *testing.T) {
	// New-format site JSON with rawConfig
	rawConfig := map[string]interface{}{
		"pki": map[string]interface{}{
			"ca":   "-----BEGIN NEBULA CERTIFICATE-----\nCpEBCg9EZWZpbmVkIHJvb3QgMDISE4CAhFCA/v//D4CCoIUMgID8/w8aE4CAgFCA\n/v//D4CAoIUMgID8/w8iBHRlc3QiBmxhcHRvcCIFcGhvbmUiCGVtcGxveWVlIgVh\nZG1pbiiI05z1BTCIuqGEBjogV/nxuQ1/kN12IrYs/H1cpZr3agQUnRs9FqWdJcOa\nJSlAARJA4H1wI3hdfVpIy8Y9IZHqIlMIFObCu5ceM4aELiTKsEGv+g7u8Dn1VY8g\nQPNsuOsqJB3ma8PntddPYn5QgH+qDA==\n-----END NEBULA CERTIFICATE-----\n",
			"cert": "-----BEGIN NEBULA CERTIFICATE-----\nCmcKCmNocm9tZWJvb2sSCYmAhFCA/v//DyiR1Zf2BTCHuqGEBjogqtoJL9WKGKLp\nb3BIgTEZnTTusSJOiswuf1DS7jPjMzFKIIstsyPnnccgEYkNflwrYBvZFMCOtgmN\nuc5Jpc5lbzM9EkBACYP3VMFYHk2h5AcpURcG6QwS4iYOgHET7lMbM7WSMj4ZnzLR\ni2HhX58vSTr6evgvKuSPaA23hLUqR65QNRQD\n-----END NEBULA CERTIFICATE-----\n",
		},
		"static_host_map": map[string]interface{}{
			"10.1.0.1": []interface{}{"10.1.1.53:4242"},
		},
		"lighthouse": map[string]interface{}{
			"hosts":    []interface{}{"10.1.0.1"},
			"interval": 7200,
		},
		"listen": map[string]interface{}{
			"host": "[::]",
			"port": 4242,
		},
		"tun": map[string]interface{}{
			"mtu": 1300,
			"unsafe_routes": []interface{}{
				map[string]interface{}{"route": "10.3.3.3/32", "via": "10.1.0.1"},
				map[string]interface{}{"route": "1.1.1.2/32", "via": "10.1.0.1"},
			},
		},
		"cipher": "aes",
		"logging": map[string]interface{}{
			"level": "info",
		},
	}

	rawConfigBytes, err := json.Marshal(rawConfig)
	require.NoError(t, err)

	sortKey := 3
	siteJSON := map[string]interface{}{
		"name":          "Debug Test - unsafe",
		"id":            "be9d6756-4099-4b25-a901-9d3b773e7d1a",
		"sortKey":       sortKey,
		"managed":       false,
		"rawConfig":     string(rawConfigBytes),
		"configVersion": 1,
	}

	configData, err := json.Marshal(siteJSON)
	require.NoError(t, err)

	s, err := RenderConfig(string(configData), "")
	require.NoError(t, err, "RenderConfig failed")

	config := nebcfg.NewC(slog.New(slog.DiscardHandler))
	err = config.LoadString(s)
	require.NoError(t, err, "LoadString failed")

	assert.Equal(t, 4242, config.GetInt("listen.port", 0))
	assert.Equal(t, "aes", config.GetString("cipher", ""))
}

func TestRenderConfigLegacy(t *testing.T) {
	// Old-format site JSON without rawConfig (legacy)
	jsonConfig := `{
  "name": "Debug Test - unsafe",
  "id": "be9d6756-4099-4b25-a901-9d3b773e7d1a",
  "staticHostmap": {
    "10.1.0.1": {
      "lighthouse": true,
      "destinations": [
        "10.1.1.53:4242"
      ]
    }
  },
  "unsafeRoutes": [
    {
      "route": "10.3.3.3/32",
      "via": "10.1.0.1",
      "mtu": null
    },
    {
      "route": "1.1.1.2/32",
      "via": "10.1.0.1",
      "mtu": null
    }
  ],
  "ca": "-----BEGIN NEBULA CERTIFICATE-----\nCpEBCg9EZWZpbmVkIHJvb3QgMDISE4CAhFCA/v//D4CCoIUMgID8/w8aE4CAgFCA\n/v//D4CAoIUMgID8/w8iBHRlc3QiBmxhcHRvcCIFcGhvbmUiCGVtcGxveWVlIgVh\nZG1pbiiI05z1BTCIuqGEBjogV/nxuQ1/kN12IrYs/H1cpZr3agQUnRs9FqWdJcOa\nJSlAARJA4H1wI3hdfVpIy8Y9IZHqIlMIFObCu5ceM4aELiTKsEGv+g7u8Dn1VY8g\nQPNsuOsqJB3ma8PntddPYn5QgH+qDA==\n-----END NEBULA CERTIFICATE-----\n",
  "cert": "-----BEGIN NEBULA CERTIFICATE-----\nCmcKCmNocm9tZWJvb2sSCYmAhFCA/v//DyiR1Zf2BTCHuqGEBjogqtoJL9WKGKLp\nb3BIgTEZnTTusSJOiswuf1DS7jPjMzFKIIstsyPnnccgEYkNflwrYBvZFMCOtgmN\nuc5Jpc5lbzM9EkBACYP3VMFYHk2h5AcpURcG6QwS4iYOgHET7lMbM7WSMj4ZnzLR\ni2HhX58vSTr6evgvKuSPaA23hLUqR65QNRQD\n-----END NEBULA CERTIFICATE-----\n",
  "key": null,
  "lhDuration": 7200,
  "port": 4242,
  "mtu": 1300,
  "cipher": "aes",
  "sortKey": 3,
  "logVerbosity": "info"
}`
	s, err := RenderConfig(jsonConfig, "")
	require.NoError(t, err, "RenderConfig (legacy) failed")

	config := nebcfg.NewC(slog.New(slog.DiscardHandler))
	err = config.LoadString(s)
	require.NoError(t, err, "LoadString (legacy) failed")
}

func TestMigrateConfig(t *testing.T) {
	// Old-format site JSON — unmanaged
	oldConfig := `{
  "name": "Test Site",
  "id": "test-id-123",
  "staticHostmap": {
    "10.1.0.1": {
      "lighthouse": true,
      "destinations": ["10.1.1.53:4242"]
    }
  },
  "unsafeRoutes": [],
  "ca": "test-ca",
  "cert": "test-cert",
  "key": null,
  "lhDuration": 60,
  "port": 4242,
  "mtu": 1300,
  "cipher": "aes",
  "sortKey": 1,
  "logVerbosity": "info",
  "managed": false
}`

	newConfig, err := MigrateConfig(oldConfig, "test-key")
	require.NoError(t, err, "MigrateConfig failed")

	var newSite map[string]interface{}
	err = json.Unmarshal([]byte(newConfig), &newSite)
	require.NoError(t, err, "Failed to parse migrated config")

	assert.Equal(t, "Test Site", newSite["name"])
	assert.Equal(t, "test-id-123", newSite["id"])
	assert.NotEmpty(t, newSite["rawConfig"])

	// Unmanaged sites must remain unmanaged after migration (was a bug: jsonTrue forced true)
	assert.Equal(t, false, newSite["managed"], "unmanaged site should stay unmanaged after migration")

	// Verify rawConfig contains the expected fields
	var rawConfig map[string]interface{}
	err = json.Unmarshal([]byte(newSite["rawConfig"].(string)), &rawConfig)
	require.NoError(t, err, "Failed to parse rawConfig")

	assert.Equal(t, "aes", rawConfig["cipher"])
}

func TestMigrateConfig_ManagedSite(t *testing.T) {
	// Old-format managed site
	oldConfig := `{
  "name": "Managed Site",
  "id": "managed-id-456",
  "staticHostmap": {},
  "unsafeRoutes": [],
  "ca": "test-ca",
  "cert": "test-cert",
  "lhDuration": 60,
  "port": 4242,
  "mtu": 1300,
  "cipher": "aes",
  "sortKey": 0,
  "logVerbosity": "info",
  "managed": true
}`

	newConfig, err := MigrateConfig(oldConfig, "test-key")
	require.NoError(t, err)

	var newSite map[string]interface{}
	err = json.Unmarshal([]byte(newConfig), &newSite)
	require.NoError(t, err)

	assert.Equal(t, true, newSite["managed"], "managed site should stay managed after migration")
}

func TestMigrateConfig_ConfigVersion(t *testing.T) {
	oldConfig := `{
  "name": "Test",
  "id": "test-id",
  "staticHostmap": {},
  "unsafeRoutes": [],
  "ca": "ca",
  "cert": "cert",
  "lhDuration": 60,
  "port": 4242,
  "mtu": 1300,
  "cipher": "aes",
  "sortKey": 0,
  "logVerbosity": "info"
}`

	newConfig, err := MigrateConfig(oldConfig, "key")
	require.NoError(t, err)

	var newSite map[string]interface{}
	err = json.Unmarshal([]byte(newConfig), &newSite)
	require.NoError(t, err)

	assert.Equal(t, float64(CurrentConfigVersion), newSite["configVersion"],
		"MigrateConfig should run the whole chain, not stop at v1")
}

func TestMigrateConfig_KeyStripped(t *testing.T) {
	oldConfig := `{
  "name": "Test",
  "id": "test-id",
  "staticHostmap": {},
  "unsafeRoutes": [],
  "ca": "ca",
  "cert": "cert",
  "lhDuration": 60,
  "port": 4242,
  "mtu": 1300,
  "cipher": "aes",
  "sortKey": 0,
  "logVerbosity": "info"
}`

	newConfig, err := MigrateConfig(oldConfig, "my-secret-key")
	require.NoError(t, err)

	var newSite map[string]interface{}
	err = json.Unmarshal([]byte(newConfig), &newSite)
	require.NoError(t, err)

	// Key should not be in the top-level site JSON (stored separately)
	assert.Nil(t, newSite["key"], "key should be nil in migrated config")

	// pki.key should be stripped from rawConfig
	var rawConfig map[string]interface{}
	err = json.Unmarshal([]byte(newSite["rawConfig"].(string)), &rawConfig)
	require.NoError(t, err)

	if pki, ok := rawConfig["pki"].(map[string]interface{}); ok {
		assert.NotContains(t, pki, "key", "pki.key should be stripped from rawConfig")
	}
}

func TestMigrateConfig_DnsResolvers(t *testing.T) {
	// Old-format site with dnsResolvers. v1 parks them under mobile_nebula and v2 hoists them
	// back to the top level, so a full chain run should land them there.
	oldConfig := `{
  "name": "DNS Test",
  "id": "dns-test-id",
  "staticHostmap": {},
  "unsafeRoutes": [],
  "ca": "ca",
  "cert": "cert",
  "lhDuration": 60,
  "port": 4242,
  "mtu": 1300,
  "cipher": "aes",
  "sortKey": 0,
  "logVerbosity": "info",
  "dnsResolvers": ["1.1.1.1", "8.8.8.8"]
}`

	newConfig, err := MigrateConfig(oldConfig, "key")
	require.NoError(t, err)

	var newSite map[string]interface{}
	err = json.Unmarshal([]byte(newConfig), &newSite)
	require.NoError(t, err)

	var rawConfig map[string]interface{}
	err = json.Unmarshal([]byte(newSite["rawConfig"].(string)), &rawConfig)
	require.NoError(t, err)

	// The local override is a first class field, rawConfig belongs to DN
	assert.Equal(t, []interface{}{"1.1.1.1", "8.8.8.8"}, newSite["dnsResolvers"])
	assert.NotContains(t, rawConfig, "mobile_nebula", "dns settings should not be left in rawConfig")
}

func TestMigrateConfig_NoDnsResolvers(t *testing.T) {
	// Old-format site without dnsResolvers — mobile_nebula key should not be created
	oldConfig := `{
  "name": "No DNS Test",
  "id": "no-dns-test-id",
  "staticHostmap": {},
  "unsafeRoutes": [],
  "ca": "ca",
  "cert": "cert",
  "lhDuration": 60,
  "port": 4242,
  "mtu": 1300,
  "cipher": "aes",
  "sortKey": 0,
  "logVerbosity": "info"
}`

	newConfig, err := MigrateConfig(oldConfig, "key")
	require.NoError(t, err)

	var newSite map[string]interface{}
	err = json.Unmarshal([]byte(newConfig), &newSite)
	require.NoError(t, err)

	var rawConfig map[string]interface{}
	err = json.Unmarshal([]byte(newSite["rawConfig"].(string)), &rawConfig)
	require.NoError(t, err)

	assert.NotContains(t, rawConfig, "mobile_nebula", "mobile_nebula key should not exist when no dnsResolvers")
}

func TestMigrateConfig_ManagedWithRawConfig(t *testing.T) {
	// Old managed site that already has a rawConfig (YAML) from DN enrollment
	oldConfig := `{
  "name": "DN Site",
  "id": "dn-id-789",
  "staticHostmap": {},
  "unsafeRoutes": [],
  "ca": "ca",
  "cert": "cert",
  "lhDuration": 60,
  "port": 4242,
  "mtu": 1300,
  "cipher": "aes",
  "sortKey": 0,
  "logVerbosity": "info",
  "managed": true,
  "rawConfig": "pki:\n  ca: dn-ca\n  cert: dn-cert\n  key: dn-key\ncipher: aes\nlisten:\n  port: 4242\n"
}`

	newConfig, err := MigrateConfig(oldConfig, "key")
	require.NoError(t, err)

	var newSite map[string]interface{}
	err = json.Unmarshal([]byte(newConfig), &newSite)
	require.NoError(t, err)

	assert.Equal(t, true, newSite["managed"])
	assert.Equal(t, float64(CurrentConfigVersion), newSite["configVersion"])

	// rawConfig should be JSON (converted from old YAML)
	var rawConfig map[string]interface{}
	err = json.Unmarshal([]byte(newSite["rawConfig"].(string)), &rawConfig)
	require.NoError(t, err, "rawConfig should be valid JSON after migration")

	assert.Equal(t, "aes", rawConfig["cipher"])

	// pki.key should be stripped
	if pki, ok := rawConfig["pki"].(map[string]interface{}); ok {
		assert.NotContains(t, pki, "key", "pki.key should be stripped from rawConfig")
	}
}

func TestDefaultRawConfig(t *testing.T) {
	rawConfig, err := DefaultRawConfig()
	require.NoError(t, err, "DefaultRawConfig failed")

	var config map[string]interface{}
	err = json.Unmarshal([]byte(rawConfig), &config)
	require.NoError(t, err, "Failed to parse default config")

	assert.Equal(t, "aes", config["cipher"])

	// Verify pki.key is not present
	if pki, ok := config["pki"].(map[string]interface{}); ok {
		assert.NotContains(t, pki, "key", "pki.key should not be present in default config")
	}
}

func TestYamlToJson(t *testing.T) {
	yamlStr := `
pki:
  ca: test-ca
  cert: test-cert
listen:
  port: 4242
cipher: aes
`
	jsonStr, err := YamlToJson(yamlStr)
	require.NoError(t, err, "YamlToJson failed")

	var result map[string]interface{}
	err = json.Unmarshal([]byte(jsonStr), &result)
	require.NoError(t, err, "Failed to parse JSON")

	assert.Equal(t, "aes", result["cipher"])

	pki, ok := result["pki"].(map[string]interface{})
	require.True(t, ok, "pki should be a map")
	assert.Equal(t, "test-ca", pki["ca"])
}

// migrateV2 runs a v1 config through MigrateConfig and returns the site map plus its rawConfig.
func migrateV2(t *testing.T, configJSON string) (map[string]interface{}, map[string]interface{}) {
	t.Helper()

	newConfig, err := MigrateConfig(configJSON, "")
	require.NoError(t, err)

	var site map[string]interface{}
	require.NoError(t, json.Unmarshal([]byte(newConfig), &site))

	rawConfig := map[string]interface{}{}
	if s, ok := site["rawConfig"].(string); ok && s != "" {
		require.NoError(t, json.Unmarshal([]byte(s), &rawConfig))
	}

	return site, rawConfig
}

func TestMigrateConfigV2_HoistsDnsSettings(t *testing.T) {
	rawConfig := `{"pki":{"cert":"c"},"listen":{"port":4242},"mobile_nebula":{"dns_resolvers":["1.1.1.1","8.8.8.8"],"match_domains":["example.com"]}}`
	configJSON := `{"name":"n","id":"i","configVersion":1,"rawConfig":` + strconv.Quote(rawConfig) + `}`

	site, newRaw := migrateV2(t, configJSON)

	assert.Equal(t, []interface{}{"1.1.1.1", "8.8.8.8"}, site["dnsResolvers"])
	assert.Equal(t, []interface{}{"example.com"}, site["matchDomains"])
	assert.Equal(t, float64(2), site["configVersion"])

	// The values must move, not copy. A leftover would read back as an admin supplied list.
	assert.NotContains(t, newRaw, "mobile_nebula", "empty mobile_nebula should be dropped")

	// Everything else in rawConfig is untouched, including number types
	listen, ok := newRaw["listen"].(map[string]interface{})
	require.True(t, ok)
	assert.Equal(t, float64(4242), listen["port"])
}

func TestMigrateConfigV2_KeepsOtherMobileNebulaKeys(t *testing.T) {
	rawConfig := `{"mobile_nebula":{"dns_resolvers":["1.1.1.1"],"allow_local_dns_override":false}}`
	configJSON := `{"name":"n","id":"i","configVersion":1,"rawConfig":` + strconv.Quote(rawConfig) + `}`

	site, newRaw := migrateV2(t, configJSON)

	assert.Equal(t, []interface{}{"1.1.1.1"}, site["dnsResolvers"])

	mobileNebula, ok := newRaw["mobile_nebula"].(map[string]interface{})
	require.True(t, ok, "mobile_nebula should survive when it still holds keys")
	assert.Equal(t, false, mobileNebula["allow_local_dns_override"])
	assert.NotContains(t, mobileNebula, "dns_resolvers")
}

func TestMigrateConfigV2_NoDnsSettings(t *testing.T) {
	rawConfig := `{"pki":{"cert":"c"}}`
	configJSON := `{"name":"n","id":"i","configVersion":1,"rawConfig":` + strconv.Quote(rawConfig) + `}`

	site, newRaw := migrateV2(t, configJSON)

	assert.NotContains(t, site, "dnsResolvers", "no local override should be invented")
	assert.NotContains(t, site, "matchDomains")
	assert.Equal(t, float64(2), site["configVersion"])
	assert.Contains(t, newRaw, "pki")
}

func TestMigrateConfigV2_EmptyListIsPreserved(t *testing.T) {
	// An empty list means the user explicitly cleared their resolvers, which is different from
	// never having set any. Absent falls back to the admin's list, empty does not.
	rawConfig := `{"mobile_nebula":{"dns_resolvers":[]}}`
	configJSON := `{"name":"n","id":"i","configVersion":1,"rawConfig":` + strconv.Quote(rawConfig) + `}`

	site, _ := migrateV2(t, configJSON)

	require.Contains(t, site, "dnsResolvers")
	assert.Equal(t, []interface{}{}, site["dnsResolvers"])
}

func TestMigrateConfigV2_IsIdempotent(t *testing.T) {
	rawConfig := `{"mobile_nebula":{"dns_resolvers":["1.1.1.1"]}}`
	configJSON := `{"name":"n","id":"i","configVersion":1,"rawConfig":` + strconv.Quote(rawConfig) + `}`

	once, err := MigrateConfig(configJSON, "")
	require.NoError(t, err)
	twice, err := MigrateConfig(once, "")
	require.NoError(t, err)

	assert.JSONEq(t, once, twice)
}

func TestMigrateConfigV2_ChainsFromV0(t *testing.T) {
	// A legacy site migrates v0 -> v1 -> v2 and lands with its resolvers at the top level
	oldConfig := `{
  "name": "Chained",
  "id": "chained-id",
  "staticHostmap": {},
  "unsafeRoutes": [],
  "ca": "ca",
  "cert": "cert",
  "lhDuration": 60,
  "port": 4242,
  "mtu": 1300,
  "cipher": "aes",
  "sortKey": 0,
  "logVerbosity": "info",
  "dnsResolvers": ["1.1.1.1", "8.8.8.8"]
}`

	site, newRaw := migrateV2(t, oldConfig)

	assert.Equal(t, []interface{}{"1.1.1.1", "8.8.8.8"}, site["dnsResolvers"])
	assert.NotContains(t, newRaw, "mobile_nebula")
	assert.Equal(t, float64(2), site["configVersion"])
}

func TestMigrateConfigV2_BadRawConfigErrors(t *testing.T) {
	configJSON := `{"name":"n","id":"i","configVersion":1,"rawConfig":"not json"}`

	_, err := MigrateConfig(configJSON, "")
	assert.Error(t, err, "a corrupt rawConfig should not be silently dropped")
}

func TestMigrateConfig_CurrentVersionIsVerbatim(t *testing.T) {
	// Kotlin and Swift skip the disk write by comparing strings, so a no-op has to be byte
	// identical rather than merely equivalent
	configJSON := `{"name":"n","id":"i","configVersion":2,"rawConfig":"{}","dnsResolvers":["1.1.1.1"]}`

	result, err := MigrateConfig(configJSON, "")
	require.NoError(t, err)
	assert.Equal(t, configJSON, result)
}

func TestMigrateConfig_FutureVersionIsLeftAlone(t *testing.T) {
	// An older build should not mangle a config a newer one wrote
	configJSON := `{"name":"n","id":"i","configVersion":99,"rawConfig":"{}"}`

	result, err := MigrateConfig(configJSON, "")
	require.NoError(t, err)
	assert.Equal(t, configJSON, result)
}

func TestMigrateConfig_BadJsonErrors(t *testing.T) {
	_, err := MigrateConfig("not json", "")
	assert.Error(t, err)
}

func TestMigrationNeedsKey(t *testing.T) {
	// Only the legacy format needs it, everything else avoids a keychain hit per site load
	assert.True(t, MigrationNeedsKey(`{"name":"n","id":"i"}`), "a v0 config has no version stamp")
	assert.True(t, MigrationNeedsKey(`{"name":"n","id":"i","configVersion":0}`))
	assert.False(t, MigrationNeedsKey(`{"name":"n","id":"i","configVersion":1}`))
	assert.False(t, MigrationNeedsKey(`{"name":"n","id":"i","configVersion":2}`))

	// Unparseable falls back to asking for the key, MigrateConfig reports the real failure
	assert.True(t, MigrationNeedsKey("not json"))
}
