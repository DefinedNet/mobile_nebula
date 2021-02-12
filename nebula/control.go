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

func (n *Nebula) Log(v string) {
	n.l.Println(v)
}

func (n *Nebula) Start() {
	n.c.Start()
}

func (n *Nebula) ShutdownBlock() {
	n.c.ShutdownBlock()
}

func (n *Nebula) Stop() {
	n.c.Stop()
}

func (n *Nebula) Rebind(reason string) {
	n.l.Infof("Rebinding UDP listener and updating lighthouses due to %s", reason)
	n.c.RebindUDPServer()
}

func (n *Nebula) ListHostmap(pending bool) (string, error) {
	hosts := n.c.ListHostmap(pending)
	b, err := json.Marshal(hosts)
	if err != nil {
		return "", err
	}

	return string(b), nil
}

func (n *Nebula) GetHostInfoByVpnIp(vpnIp string, pending bool) (string, error) {
	b, err := json.Marshal(n.c.GetHostInfoByVpnIP(stringIpToInt(vpnIp), pending))
	if err != nil {
		return "", err
	}

	return string(b), nil
}

func (n *Nebula) CloseTunnel(vpnIp string) bool {
	return n.c.CloseTunnel(stringIpToInt(vpnIp), false)
}

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

func (n *Nebula) Sleep() {
	if closed := n.c.CloseAllTunnels(true); closed > 0 {
		n.l.WithField("tunnels", closed).Info("Sleep called, closed non lighthouse tunnels")
	}
}

func stringIpToInt(ip string) uint32 {
	n := net.ParseIP(ip)
	if len(n) == 16 {
		return binary.BigEndian.Uint32(n[12:16])
	}
	return binary.BigEndian.Uint32(n)
}
