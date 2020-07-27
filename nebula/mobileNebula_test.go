package mobileNebula

import (
	"testing"

	"github.com/slackhq/nebula"
)

func TestParseCerts(t *testing.T) {
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

	config := nebula.NewConfig()
	err = config.LoadString(s)

	t.Log(err)
	return
}
