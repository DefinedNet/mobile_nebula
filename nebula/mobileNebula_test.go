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
	// Old-format site JSON
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
	assert.Equal(t, float64(1), newSite["configVersion"])

	// Verify rawConfig contains the expected fields
	var rawConfig map[string]interface{}
	err = json.Unmarshal([]byte(newSite["rawConfig"].(string)), &rawConfig)
	require.NoError(t, err, "Failed to parse rawConfig")

	assert.Equal(t, "aes", rawConfig["cipher"])

	// Verify pki.key was stripped from rawConfig
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
