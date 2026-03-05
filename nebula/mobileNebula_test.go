package mobileNebula

import (
	"encoding/json"
	"testing"

	"github.com/sirupsen/logrus"
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

	config := nebcfg.NewC(logrus.New())
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

	config := nebcfg.NewC(logrus.New())
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

	assert.Equal(t, float64(1), newSite["configVersion"], "migrated config should have configVersion 1")
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
	// Old-format site with dnsResolvers — should be preserved under mobile_nebula.dns_resolvers
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

	// dnsResolvers should be under mobile_nebula namespace
	mobileNebula, ok := rawConfig["mobile_nebula"].(map[string]interface{})
	require.True(t, ok, "rawConfig should have mobile_nebula key")

	resolvers, ok := mobileNebula["dns_resolvers"].([]interface{})
	require.True(t, ok, "mobile_nebula should have dns_resolvers")
	assert.Equal(t, []interface{}{"1.1.1.1", "8.8.8.8"}, resolvers)

	// dnsResolvers should NOT be at the top level of rawConfig
	assert.NotContains(t, rawConfig, "dnsResolvers", "dnsResolvers should not be at rawConfig top level")
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
	assert.Equal(t, float64(1), newSite["configVersion"])

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
