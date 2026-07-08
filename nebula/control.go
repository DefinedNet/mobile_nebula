package mobileNebula

import (
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/netip"
	"os"
	"runtime"
	"runtime/debug"
	"sync"

	"github.com/slackhq/nebula"
	nc "github.com/slackhq/nebula/config"
	"github.com/slackhq/nebula/logging"
	"github.com/slackhq/nebula/overlay"
	"github.com/slackhq/nebula/util"
	"golang.org/x/sys/unix"
)

// ExitCallback is implemented by the platform side (Kotlin/Swift) to learn about
// nebula dying from a fatal packet reader error, without this the OS still
// thinks the tunnel is up while traffic blackholes. A clean Stop never fires
// it. A fatal error that races a platform requested stop can, both platforms
// gate that out with their own stop tracking. The callback fires from a Go
// thread, hop to the platform main thread before touching anything that needs it.
type ExitCallback interface {
	OnExit(message string)
}

type Nebula struct {
	c      *nebula.Control
	l      *slog.Logger
	config *nc.C

	logFile      *os.File
	closeLogOnce sync.Once

	// lifecycle serializes Stop and Reload so a reload cannot fire config
	// callbacks, which reach raw fds via setsockopt and sendto, into an
	// interface a platform stop has torn down
	lifecycle sync.Mutex
}

func init() {
	// Reduces memory utilization according to https://twitter.com/felixge/status/1355846360562589696?s=20
	runtime.MemProfileRate = 0
}

func NewNebula(configData string, key string, logFile string, tunFd int) (_ *Nebula, reterr error) {
	// GC more often, largely for iOS due to extension 15mb limit
	debug.SetGCPercent(20)

	// nebula only owns tunFd once its device factory has actually run, a failure
	// before that (config parsing here, pki or firewall errors inside Main) leaves
	// the fd with us and we must close it. Android detaches its fd to us and the
	// system keeps the VPN routes pointed at a dead tun until it closes, iOS hands
	// us a dup that only we hold.
	fdHandedOff := false
	defer func() {
		if reterr != nil && !fdHandedOff {
			_ = unix.Close(tunFd)
		}
	}()

	yamlConfig, err := RenderConfig(configData, key)
	if err != nil {
		return nil, err
	}

	f, err := os.OpenFile(logFile, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0644)
	if err != nil {
		return nil, err
	}

	// The logger owns f on success, close it ourselves on any error return so
	// repeated failed starts in the long lived app process don't pile up fds
	defer func() {
		if reterr != nil {
			f.Close()
		}
	}()

	l := logging.NewLogger(f)

	c := nc.NewC(l)
	err = c.LoadString(yamlConfig)
	if err != nil {
		return nil, fmt.Errorf("failed to load config: %s", err)
	}

	// nebula.Main does not configure the logger from config, so apply
	// logging.level/format ourselves and keep it in sync on reload.
	if err := logging.ApplyConfig(l, c); err != nil {
		return nil, fmt.Errorf("failed to apply logging config: %s", err)
	}
	c.RegisterReloadCallback(func(c *nc.C) {
		if err := logging.ApplyConfig(l, c); err != nil {
			l.Error("Failed to reconfigure logger on reload", "error", err)
		}
	})

	devFactory := overlay.NewFdDeviceFromConfig(&tunFd)
	wrappedFactory := func(c *nc.C, l *slog.Logger, vpnNetworks []netip.Prefix, routines int) (overlay.Device, error) {
		// nebula owns the fd from here, even on failure it closes it along with
		// the udp sockets it bound
		fdHandedOff = true
		return devFactory(c, l, vpnNetworks, routines)
	}

	//TODO: inject our version
	ctrl, err := nebula.Main(c, false, "", l, wrappedFactory)
	if err != nil {
		return nil, logAndUnwrap("Failed to start", err, l)
	}

	return &Nebula{c: ctrl, l: l, config: c, logFile: f}, nil
}

// logAndUnwrap logs err with its context fields attached and returns the inner
// error, a ContextualError's string includes a raw fields map that we don't
// want surfaced in the platform UI
func logAndUnwrap(msg string, err error, l *slog.Logger) error {
	util.LogWithContextIfNeeded(msg, err, l)
	var ce *util.ContextualError
	if errors.As(err, &ce) {
		return ce.Unwrap()
	}
	return err
}

// Start brings the tunnel up. A Nebula is single use, a Start after a Stop
// returns an error, both platforms build a fresh instance per connect.
func (n *Nebula) Start(cb ExitCallback) error {
	if err := n.c.Start(); err != nil {
		return logAndUnwrap("Failed to start nebula", err, n.l)
	}

	// A fatal packet reader error stops nebula internally, tell the platform
	// side so it can tear the tunnel down instead of blackholing traffic. A
	// requested stop waits out as nil upstream only when no fatal error
	// occurred, the platform callbacks gate out the raced case themselves.
	go func() {
		if err := n.c.Wait(); err != nil {
			n.l.Error("Nebula stopped due to fatal error", "error", err)
			if cb != nil {
				cb.OnExit(err.Error())
			}
		}
	}()

	return nil
}

// Stop tears nebula down and blocks until the packet readers have drained, so
// when it returns the tunnel is fully stopped. Safe to call at any point in
// the lifecycle, a Stop that lands before Start poisons the instance and that
// Start will refuse to run.
func (n *Nebula) Stop() {
	n.lifecycle.Lock()
	defer n.lifecycle.Unlock()

	n.c.Stop()
	_ = n.c.Wait()

	// The instance is single use and fully stopped, release the log file
	// deterministically instead of leaving it to a GC finalizer, the Android
	// app process is long lived and opens a fresh one per connect
	n.closeLogOnce.Do(func() {
		_ = n.logFile.Close()
	})
}

func (n *Nebula) Rebind(reason string) {
	// RebindUDPServer is a no-op if nebula is not started, so it is safe to
	// call from a network change handler racing a stop
	n.l.Debug("Rebinding UDP listener and updating lighthouses", "reason", reason)
	n.c.RebindUDPServer()
}

func (n *Nebula) Reload(configData string, key string) error {
	yamlConfig, err := RenderConfig(configData, key)
	if err != nil {
		return err
	}

	n.lifecycle.Lock()
	defer n.lifecycle.Unlock()

	// Don't fire reload callbacks into an interface that is coming down, the
	// iOS DN updater timer can land a reload around a stop. The lock makes the
	// check atomic with a platform stop, a nebula internal fatal stop can still
	// slip a reload into its teardown but those callbacks only see closed fds.
	if n.c.State() != nebula.StateStarted {
		return nil
	}

	n.l.Info("Reloading Nebula")
	return n.config.ReloadConfigString(yamlConfig)
}

func (n *Nebula) ListHostmap(pending bool) (string, error) {
	hosts := n.c.ListHostmapHosts(pending)
	b, err := json.Marshal(hosts)
	if err != nil {
		return "", err
	}

	return string(b), nil
}

func (n *Nebula) ListIndexes(pending bool) (string, error) {
	indexes := n.c.ListHostmapIndexes(pending)
	b, err := json.Marshal(indexes)
	if err != nil {
		return "", err
	}

	return string(b), nil
}

func (n *Nebula) GetHostInfoByVpnIp(vpnIp string, pending bool) (string, error) {
	netVpnIp, err := netip.ParseAddr(vpnIp)
	if err != nil {
		return "", err
	}

	b, err := json.Marshal(n.c.GetHostInfoByVpnAddr(netVpnIp, pending))
	if err != nil {
		return "", err
	}

	return string(b), nil
}

func (n *Nebula) CloseTunnel(vpnIp string) bool {
	netVpnIp, err := netip.ParseAddr(vpnIp)
	if err != nil {
		return false
	}

	return n.c.CloseTunnel(netVpnIp, false)
}

func (n *Nebula) SetRemoteForTunnel(vpnIp string, addr string) (string, error) {
	udpAddr, err := netip.ParseAddrPort(addr)
	if err != nil {
		return "", errors.New("could not parse udp address")
	}

	netVpnIp, err := netip.ParseAddr(vpnIp)
	if err != nil {
		return "", errors.New("could not parse vpnIp")
	}

	b, err := json.Marshal(n.c.SetRemoteForTunnel(netVpnIp, udpAddr))
	if err != nil {
		return "", err
	}

	return string(b), nil
}

func (n *Nebula) Sleep() {
	if closed := n.c.CloseAllTunnels(true); closed > 0 {
		n.l.Info("Sleep called, closed non lighthouse tunnels", "tunnels", closed)
	}
}
