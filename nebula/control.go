package mobileNebula

import (
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"os"
	"runtime"
	"runtime/debug"

	"github.com/sirupsen/logrus"
	"github.com/slackhq/nebula"
	nc "github.com/slackhq/nebula/config"
	"github.com/slackhq/nebula/iputil"
	"github.com/slackhq/nebula/udp"
	"github.com/slackhq/nebula/util"
)

type Nebula struct {
	c *nebula.Control
	l *logrus.Logger
}

func init() {
	// Reduces memory utilization according to https://twitter.com/felixge/status/1355846360562589696?s=20
	runtime.MemProfileRate = 0
}

func NewNebula(configData string, key string, logFile string, tunFd int) (*Nebula, error) {
	// GC more often, largely for iOS due to extension 15mb limit
	debug.SetGCPercent(20)

	yamlConfig, err := RenderConfig(configData, key)
	if err != nil {
		return nil, err
	}

	l := logrus.New()
	f, err := os.OpenFile(logFile, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0644)
	if err != nil {
		return nil, err
	}
	l.SetOutput(f)

	c := nc.NewC(l)
	err = c.LoadString(yamlConfig)
	if err != nil {
		return nil, fmt.Errorf("failed to load config: %s", err)
	}

	//TODO: inject our version
	ctrl, err := nebula.Main(c, false, "", l, &tunFd)
	if err != nil {
		switch v := err.(type) {
		case util.ContextualError:
			v.Log(l)
			return nil, v.Unwrap()
		default:
			l.WithError(err).Error("Failed to start")
			return nil, err
		}
	}

	return &Nebula{ctrl, l}, nil
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
	n.l.Debugf("Rebinding UDP listener and updating lighthouses due to %s", reason)
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
	b, err := json.Marshal(n.c.GetHostInfoByVpnIp(stringIpToInt(vpnIp), pending))
	if err != nil {
		return "", err
	}

	return string(b), nil
}

func (n *Nebula) CloseTunnel(vpnIp string) bool {
	return n.c.CloseTunnel(stringIpToInt(vpnIp), false)
}

func (n *Nebula) SetRemoteForTunnel(vpnIp string, addr string) (string, error) {
	udpAddr := udp.NewAddrFromString(addr)
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

func stringIpToInt(ip string) iputil.VpnIp {
	return iputil.Ip2VpnIp(net.ParseIP(ip))
}
