//go:build stealth_novpn

package mobile

import (
	"context"
	"fmt"
	"log/slog"
	"net"
	"os"
	"strconv"
	"sync"
	"sync/atomic"

	_ "golang.org/x/mobile/bind"

	"github.com/getlantern/radiance/backend"
	"github.com/getlantern/radiance/common"
	"github.com/getlantern/radiance/vpn"

	"github.com/getlantern/lantern/lantern-core/utils"
)

var (
	proxyMu      sync.Mutex
	proxyBackend *backend.LocalBackend
	proxyActive  atomic.Bool
)

func InitLogging(dataDir, logDir, logLevel string) error {
	return runOffCgoStack(func() error {
		return common.Init(dataDir, logDir, effectiveLogLevel(logLevel))
	})
}

func StartProxy(
	dataDir string,
	logDir string,
	deviceID string,
	locale string,
	telemetryConsent bool,
	host string,
	port int,
) error {
	return runOffCgoStack(func() error {
		return startProxy(dataDir, logDir, deviceID, locale, telemetryConsent, host, port)
	})
}

func startProxy(
	dataDir string,
	logDir string,
	deviceID string,
	locale string,
	telemetryConsent bool,
	host string,
	port int,
) error {
	proxyMu.Lock()
	defer proxyMu.Unlock()

	if proxyBackend == nil {
		addr := net.JoinHostPort(host, strconv.Itoa(port))
		opts := backend.Options{
			DataDir:          dataDir,
			LogDir:           logDir,
			Locale:           locale,
			LogLevel:         effectiveLogLevel(""),
			DeviceID:         deviceID,
			TelemetryConsent: telemetryConsent,
			EnvOverrides: map[string]string{
				"RADIANCE_USE_SOCKS_PROXY": "true",
				"RADIANCE_SOCKS_ADDRESS":   addr,
			},
		}
		be, err := backend.NewLocalBackend(context.Background(), opts)
		if err != nil {
			return fmt.Errorf("create local engine: %w", err)
		}
		be.Start()
		proxyBackend = be
	}

	if proxyBackend == nil {
		return fmt.Errorf("local engine client unavailable")
	}
	if err := proxyBackend.ConnectVPN(vpn.AutoSelectTag); err != nil {
		return fmt.Errorf("start local connection: %w", err)
	}
	proxyActive.Store(true)
	slog.Info("local connection started")
	return nil
}

func StopProxy() error {
	return runOffCgoStack(stopProxy)
}

func stopProxy() error {
	proxyMu.Lock()
	defer proxyMu.Unlock()

	be := proxyBackend
	if be == nil {
		proxyActive.Store(false)
		return nil
	}
	defer func() {
		be.Close()
		proxyBackend = nil
		proxyActive.Store(false)
	}()

	if err := be.DisconnectVPN(); err != nil {
		return fmt.Errorf("stop local connection: %w", err)
	}
	return nil
}

func SelectRoute(tag string) error {
	return runOffCgoStack(func() error {
		return selectRoute(tag)
	})
}

func selectRoute(tag string) error {
	proxyMu.Lock()
	be := proxyBackend
	proxyMu.Unlock()
	if be == nil {
		return fmt.Errorf("local engine client unavailable")
	}
	return be.SelectServer(tag)
}

func IsProxyActive() bool {
	active, _ := utils.RunOffCgoStack(func() (bool, error) {
		return proxyActive.Load(), nil
	})
	return active
}

func SetQAEnvOverrides(outboundSocks, tz string) error {
	return runOffCgoStack(func() error {
		return setQAEnvOverrides(outboundSocks, tz)
	})
}

func setQAEnvOverrides(outboundSocks, tz string) error {
	if outboundSocks != "" {
		if err := os.Setenv("RADIANCE_OUTBOUND_SOCKS_ADDRESS", outboundSocks); err != nil {
			return fmt.Errorf("set outbound override: %w", err)
		}
	}
	if tz != "" {
		if err := os.Setenv("TZ", tz); err != nil {
			return fmt.Errorf("set timezone override: %w", err)
		}
	}
	return nil
}

func runOffCgoStack(fn func() error) error {
	_, err := utils.RunOffCgoStack(func() (struct{}, error) {
		return struct{}{}, fn()
	})
	return err
}

func effectiveLogLevel(configured string) string {
	if configured == "" || configured == "trace" {
		return "warn"
	}
	return configured
}
