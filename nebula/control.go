package mobileNebula

import (
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"os"
	"runtime/debug"

	"github.com/sirupsen/logrus"
	"github.com/slackhq/nebula"
)

type Nebula struct {
	c *nebula.Control
	l *logrus.Logger
}

// NewNebula assembles config and certificates to return a Nebula Client
func NewNebula(configData string, key string, logFile string, tunFd int) (*Nebula, error) {
	// GC more often, largely for iOS due to extension 15mb limit
	debug.SetGCPercent(20)

	yamlConfig, err := RenderConfig(configData, key)
	if err != nil {
		return nil, err
	}

	config := nebula.NewConfig()
	err = config.LoadString(yamlConfig)
	if err != nil {
		return nil, fmt.Errorf("failed to load config: %s", err)
	}

	l := logrus.New()

	// Set logrus output to write to logfile
	f, err := os.OpenFile(logFile, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0644)
	if err != nil {
		return nil, err
	}
	l.SetOutput(f)

	//TODO: inject our version
	c, err := nebula.Main(config, false, "", l, &tunFd)
	if err != nil {
		switch v := err.(type) {
		case nebula.ContextualError:
			v.Log(l)
			return nil, v.Unwrap()
		default:
			l.WithError(err).Error("Failed to start")
			return nil, err
		}
	}

	return &Nebula{c, l}, nil
}

// Start is a handler function for downstream libries to manage the Nebula service
func (n *Nebula) Start() {
	n.c.Start()
}

// ShutdownBlock is a handler function for downstream libries to manage the Nebula service
func (n *Nebula) ShutdownBlock() {
	n.c.ShutdownBlock()
}

// Stop is a handler function for downstream libries to manage the Nebula service
func (n *Nebula) Stop() {
	n.c.Stop()
}

// Rebind is a handler function for downstream libries to manage the Nebula service
func (n *Nebula) Rebind() {
	n.c.RebindUDPServer()
}

// ListHostmap is a handler function for downstream libries to manage the Nebula service
func (n *Nebula) ListHostmap(pending bool) (string, error) {
	hosts := n.c.ListHostmap(pending)
	b, err := json.Marshal(hosts)
	if err != nil {
		return "", err
	}

	return string(b), nil
}

// GetHostInfoByVpnIp is a handler function for downstream libries to manage the Nebula service
func (n *Nebula) GetHostInfoByVpnIp(vpnIp string, pending bool) (string, error) {
	b, err := json.Marshal(n.c.GetHostInfoByVpnIP(stringIpToInt(vpnIp), pending))
	if err != nil {
		return "", err
	}

	return string(b), nil
}

// CloseTunnel takes a VPN IP and closes the corresponding tunnel
func (n *Nebula) CloseTunnel(vpnIp string) bool {
	return n.c.CloseTunnel(stringIpToInt(vpnIp), false)
}

// SetRemoteForTunnel is a wrapper function for Nebula's SetRemoteForTunnel
func (n *Nebula) SetRemoteForTunnel(vpnIp string, addr string) (string, error) {
	udpAddr := nebula.NewUDPAddrFromString(addr)
	if udpAddr == nil {
		return "", errors.New("could not parse udp address")
	}

	b, err := json.Marshal(n.c.SetRemoteForTunnel(stringIpToInt(vpnIp), *udpAddr))
	if err != nil {
		return "", err
	}

	return string(b), nil
}

func stringIpToInt(ip string) uint32 {
	n := net.ParseIP(ip)
	if len(n) == 16 {
		return binary.BigEndian.Uint32(n[12:16])
	}
	return binary.BigEndian.Uint32(n)
}
