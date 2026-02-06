//go:build darwin

package main

/*
#include <stdlib.h>
#include <stdint.h>

// Callback typedefs for PlatformInterface
// OpenTun: opens a TUN device with the given options (JSON), returns fd via ret0_
typedef int32_t (*OpenTunCallback)(const char* tunOptionsJson, int32_t* fd);
typedef void (*ClearDNSCacheCallback)(void);
typedef void (*WriteLogCallback)(const char* message);
typedef int (*RestartServiceCallback)(void);
typedef void (*PostServiceCloseCallback)(void);
typedef int (*UsePlatformAutoDetectControlCallback)(void);
typedef char* (*ReadWIFIStateCallback)(void);
typedef int (*UnderNetworkExtensionCallback)(void);
typedef int (*IncludeAllNetworksCallback)(void);
typedef void (*SwiftEventCallback)(const char* eventJson);

// Callbacks storage struct - avoids multiple definitions
typedef struct {
    OpenTunCallback openTun;
    ClearDNSCacheCallback clearDNSCache;
    WriteLogCallback writeLog;
    RestartServiceCallback restartService;
    PostServiceCloseCallback postServiceClose;
    UsePlatformAutoDetectControlCallback usePlatformAutoDetectControl;
    ReadWIFIStateCallback readWIFIState;
    UnderNetworkExtensionCallback underNetworkExtension;
    IncludeAllNetworksCallback includeAllNetworks;
    SwiftEventCallback swiftEvent;
} PlatformCallbacks;

// Single static struct instance
static PlatformCallbacks platformCallbacks = {0};

// Wrapper functions called from Go
static inline void setPlatformCallbacks(
    OpenTunCallback openTun,
    ClearDNSCacheCallback clearDNSCache,
    WriteLogCallback writeLog,
    RestartServiceCallback restartService,
    PostServiceCloseCallback postServiceClose,
    UsePlatformAutoDetectControlCallback usePlatformAutoDetectControl,
    ReadWIFIStateCallback readWIFIState,
    UnderNetworkExtensionCallback underNetworkExtension,
    IncludeAllNetworksCallback includeAllNetworks
) {
    platformCallbacks.openTun = openTun;
    platformCallbacks.clearDNSCache = clearDNSCache;
    platformCallbacks.writeLog = writeLog;
    platformCallbacks.restartService = restartService;
    platformCallbacks.postServiceClose = postServiceClose;
    platformCallbacks.usePlatformAutoDetectControl = usePlatformAutoDetectControl;
    platformCallbacks.readWIFIState = readWIFIState;
    platformCallbacks.underNetworkExtension = underNetworkExtension;
    platformCallbacks.includeAllNetworks = includeAllNetworks;
}

static inline void setSwiftEventCallback(SwiftEventCallback cb) {
    platformCallbacks.swiftEvent = cb;
}

static inline int hasPlatformCallbacksSet(void) {
    return platformCallbacks.openTun != NULL;
}

static inline int32_t callOpenTun(const char* opts, int32_t* fd) {
    if (platformCallbacks.openTun != NULL) {
        return platformCallbacks.openTun(opts, fd);
    }
    return -1;
}

static inline void callClearDNSCache(void) {
    if (platformCallbacks.clearDNSCache != NULL) {
        platformCallbacks.clearDNSCache();
    }
}

static inline void callWriteLog(const char* message) {
    if (platformCallbacks.writeLog != NULL) {
        platformCallbacks.writeLog(message);
    }
}

static inline int callRestartService(void) {
    if (platformCallbacks.restartService != NULL) {
        return platformCallbacks.restartService();
    }
    return -1;
}

static inline void callPostServiceClose(void) {
    if (platformCallbacks.postServiceClose != NULL) {
        platformCallbacks.postServiceClose();
    }
}

static inline int callUsePlatformAutoDetectControl(void) {
    if (platformCallbacks.usePlatformAutoDetectControl != NULL) {
        return platformCallbacks.usePlatformAutoDetectControl();
    }
    return 0;
}

static inline char* callReadWIFIState(void) {
    if (platformCallbacks.readWIFIState != NULL) {
        return platformCallbacks.readWIFIState();
    }
    return NULL;
}

static inline int callUnderNetworkExtension(void) {
    if (platformCallbacks.underNetworkExtension != NULL) {
        return platformCallbacks.underNetworkExtension();
    }
    return 0;
}

static inline int callIncludeAllNetworks(void) {
    if (platformCallbacks.includeAllNetworks != NULL) {
        return platformCallbacks.includeAllNetworks();
    }
    return 0;
}

static inline void callSwiftEventCallback(const char* eventJson) {
    if (platformCallbacks.swiftEvent != NULL) {
        platformCallbacks.swiftEvent(eventJson);
    }
}
*/
import "C"

import (
	"encoding/json"
	"errors"
	"log/slog"
	"sync"
	"unsafe"

	"github.com/sagernet/sing-box/experimental/libbox"

	"github.com/getlantern/lantern/lantern-core/utils"
	"github.com/getlantern/lantern/lantern-core/vpn_tunnel"
)

var (
	cgoPlatform     *cgoPlatformInterface
	cgoPlatformOnce sync.Once
)

// cgoPlatformInterface implements utils.PlatformInterface by calling through C function pointers
// that are registered by Swift at startup
type cgoPlatformInterface struct {
	tunOptionsMutex sync.Mutex
}

// TunOptions is a simplified struct for JSON serialization of TUN options
type TunOptions struct {
	MTU                        int32    `json:"mtu"`
	AutoRoute                  bool     `json:"autoRoute"`
	DNSServerAddress           string   `json:"dnsServerAddress"`
	Inet4Addresses             []string `json:"inet4Addresses"`
	Inet4Masks                 []string `json:"inet4Masks"`
	Inet6Addresses             []string `json:"inet6Addresses"`
	Inet6Prefixes              []int    `json:"inet6Prefixes"`
	Inet4RouteAddresses        []string `json:"inet4RouteAddresses"`
	Inet4RouteMasks            []string `json:"inet4RouteMasks"`
	Inet4RouteExcludeAddresses []string `json:"inet4RouteExcludeAddresses"`
	Inet4RouteExcludeMasks     []string `json:"inet4RouteExcludeMasks"`
	Inet6RouteAddresses        []string `json:"inet6RouteAddresses"`
	Inet6RoutePrefixes         []int    `json:"inet6RoutePrefixes"`
	Inet6RouteExcludeAddresses []string `json:"inet6RouteExcludeAddresses"`
	Inet6RouteExcludePrefixes  []int    `json:"inet6RouteExcludePrefixes"`
	HTTPProxyEnabled           bool     `json:"httpProxyEnabled"`
	HTTPProxyServer            string   `json:"httpProxyServer"`
	HTTPProxyServerPort        int32    `json:"httpProxyServerPort"`
	HTTPProxyBypassDomains     []string `json:"httpProxyBypassDomains"`
	HTTPProxyMatchDomains      []string `json:"httpProxyMatchDomains"`
}

// WIFIState represents the WIFI state returned from Swift
type WIFIState struct {
	SSID  string `json:"ssid"`
	BSSID string `json:"bssid"`
}

//export registerPlatformCallbacks
func registerPlatformCallbacks(
	openTun C.OpenTunCallback,
	clearDNSCache C.ClearDNSCacheCallback,
	writeLog C.WriteLogCallback,
	restartService C.RestartServiceCallback,
	postServiceClose C.PostServiceCloseCallback,
	usePlatformAutoDetectControl C.UsePlatformAutoDetectControlCallback,
	readWIFIState C.ReadWIFIStateCallback,
	underNetworkExtension C.UnderNetworkExtensionCallback,
	includeAllNetworks C.IncludeAllNetworksCallback,
) {
	C.setPlatformCallbacks(
		openTun,
		clearDNSCache,
		writeLog,
		restartService,
		postServiceClose,
		usePlatformAutoDetectControl,
		readWIFIState,
		underNetworkExtension,
		includeAllNetworks,
	)
	slog.Info("Platform callbacks registered")
}

//export registerSwiftEventCallback
func registerSwiftEventCallback(callback C.SwiftEventCallback) {
	C.setSwiftEventCallback(callback)
	slog.Info("Swift event callback registered")
}

// getCgoPlatform returns the singleton cgo platform interface
func getCgoPlatform() *cgoPlatformInterface {
	cgoPlatformOnce.Do(func() {
		cgoPlatform = &cgoPlatformInterface{}
	})
	return cgoPlatform
}

// hasPlatformCallbacks returns true if platform callbacks are registered
func hasPlatformCallbacks() bool {
	return C.hasPlatformCallbacksSet() != 0
}

// OpenTun opens a TUN device with the given options
func (p *cgoPlatformInterface) OpenTun(options libbox.TunOptions) (int32, error) {
	p.tunOptionsMutex.Lock()
	defer p.tunOptionsMutex.Unlock()

	if !hasPlatformCallbacks() {
		return -1, errors.New("OpenTun callback not registered")
	}

	// Convert TunOptions to our simplified JSON struct
	tunOpts := TunOptions{
		MTU:       options.GetMTU(),
		AutoRoute: options.GetAutoRoute(),
	}

	// Get DNS server address
	if dnsAddr, err := options.GetDNSServerAddress(); err == nil {
		tunOpts.DNSServerAddress = dnsAddr.Value
	}

	// Get IPv4 addresses
	if inet4Iter := options.GetInet4Address(); inet4Iter != nil {
		for inet4Iter.HasNext() {
			prefix := inet4Iter.Next()
			tunOpts.Inet4Addresses = append(tunOpts.Inet4Addresses, prefix.Address())
			tunOpts.Inet4Masks = append(tunOpts.Inet4Masks, prefix.Mask())
		}
	}

	// Get IPv6 addresses
	if inet6Iter := options.GetInet6Address(); inet6Iter != nil {
		for inet6Iter.HasNext() {
			prefix := inet6Iter.Next()
			tunOpts.Inet6Addresses = append(tunOpts.Inet6Addresses, prefix.Address())
			tunOpts.Inet6Prefixes = append(tunOpts.Inet6Prefixes, int(prefix.Prefix()))
		}
	}

	// Get IPv4 route addresses
	if inet4RouteIter := options.GetInet4RouteAddress(); inet4RouteIter != nil {
		for inet4RouteIter.HasNext() {
			prefix := inet4RouteIter.Next()
			tunOpts.Inet4RouteAddresses = append(tunOpts.Inet4RouteAddresses, prefix.Address())
			tunOpts.Inet4RouteMasks = append(tunOpts.Inet4RouteMasks, prefix.Mask())
		}
	}

	// Get IPv4 route exclude addresses
	if inet4ExcludeIter := options.GetInet4RouteExcludeAddress(); inet4ExcludeIter != nil {
		for inet4ExcludeIter.HasNext() {
			prefix := inet4ExcludeIter.Next()
			tunOpts.Inet4RouteExcludeAddresses = append(tunOpts.Inet4RouteExcludeAddresses, prefix.Address())
			tunOpts.Inet4RouteExcludeMasks = append(tunOpts.Inet4RouteExcludeMasks, prefix.Mask())
		}
	}

	// Get IPv6 route addresses
	if inet6RouteIter := options.GetInet6RouteAddress(); inet6RouteIter != nil {
		for inet6RouteIter.HasNext() {
			prefix := inet6RouteIter.Next()
			tunOpts.Inet6RouteAddresses = append(tunOpts.Inet6RouteAddresses, prefix.Address())
			tunOpts.Inet6RoutePrefixes = append(tunOpts.Inet6RoutePrefixes, int(prefix.Prefix()))
		}
	}

	// Get IPv6 route exclude addresses
	if inet6ExcludeIter := options.GetInet6RouteExcludeAddress(); inet6ExcludeIter != nil {
		for inet6ExcludeIter.HasNext() {
			prefix := inet6ExcludeIter.Next()
			tunOpts.Inet6RouteExcludeAddresses = append(tunOpts.Inet6RouteExcludeAddresses, prefix.Address())
			tunOpts.Inet6RouteExcludePrefixes = append(tunOpts.Inet6RouteExcludePrefixes, int(prefix.Prefix()))
		}
	}

	// HTTP Proxy settings
	tunOpts.HTTPProxyEnabled = options.IsHTTPProxyEnabled()
	if tunOpts.HTTPProxyEnabled {
		tunOpts.HTTPProxyServer = options.GetHTTPProxyServer()
		tunOpts.HTTPProxyServerPort = options.GetHTTPProxyServerPort()

		if bypassIter := options.GetHTTPProxyBypassDomain(); bypassIter != nil {
			for bypassIter.HasNext() {
				tunOpts.HTTPProxyBypassDomains = append(tunOpts.HTTPProxyBypassDomains, bypassIter.Next())
			}
		}
		if matchIter := options.GetHTTPProxyMatchDomain(); matchIter != nil {
			for matchIter.HasNext() {
				tunOpts.HTTPProxyMatchDomains = append(tunOpts.HTTPProxyMatchDomains, matchIter.Next())
			}
		}
	}

	// Serialize to JSON
	jsonData, err := json.Marshal(tunOpts)
	if err != nil {
		return -1, err
	}

	cOpts := C.CString(string(jsonData))
	defer C.free(unsafe.Pointer(cOpts))

	var fd C.int32_t
	result := C.callOpenTun(cOpts, &fd)
	if result != 0 {
		return -1, errors.New("failed to open TUN device")
	}

	return int32(fd), nil
}

// WriteLog writes a log message
func (p *cgoPlatformInterface) WriteLog(message string) {
	cMsg := C.CString(message)
	defer C.free(unsafe.Pointer(cMsg))
	C.callWriteLog(cMsg)
}

// UsePlatformAutoDetectInterfaceControl returns whether platform auto-detect interface control is used
func (p *cgoPlatformInterface) UsePlatformAutoDetectInterfaceControl() bool {
	return C.callUsePlatformAutoDetectControl() != 0
}

// AutoDetectInterfaceControl is called for auto-detect interface control
func (p *cgoPlatformInterface) AutoDetectInterfaceControl(fd int32) error {
	return nil
}

// FindConnectionOwner finds the owner of a connection
func (p *cgoPlatformInterface) FindConnectionOwner(ipProtocol int32, sourceAddress string, sourcePort int32, destinationAddress string, destinationPort int32) (int32, error) {
	return 0, errors.New("not implemented")
}

// PackageNameByUid returns the package name for a UID
func (p *cgoPlatformInterface) PackageNameByUid(uid int32) (string, error) {
	return "", nil
}

// UIDByPackageName returns the UID for a package name
func (p *cgoPlatformInterface) UIDByPackageName(packageName string) (int32, error) {
	return 0, errors.New("not implemented")
}

// UseProcFS returns whether to use procfs
func (p *cgoPlatformInterface) UseProcFS() bool {
	return false
}

// StartDefaultInterfaceMonitor starts the default interface monitor
func (p *cgoPlatformInterface) StartDefaultInterfaceMonitor(listener libbox.InterfaceUpdateListener) error {
	return nil
}

// CloseDefaultInterfaceMonitor closes the default interface monitor
func (p *cgoPlatformInterface) CloseDefaultInterfaceMonitor(listener libbox.InterfaceUpdateListener) error {
	return nil
}

// GetInterfaces returns the network interfaces
func (p *cgoPlatformInterface) GetInterfaces() (libbox.NetworkInterfaceIterator, error) {
	return nil, nil
}

// UnderNetworkExtension returns whether running under network extension
func (p *cgoPlatformInterface) UnderNetworkExtension() bool {
	return C.callUnderNetworkExtension() != 0
}

// IncludeAllNetworks returns whether to include all networks
func (p *cgoPlatformInterface) IncludeAllNetworks() bool {
	return C.callIncludeAllNetworks() != 0
}

// ClearDNSCache clears the DNS cache
func (p *cgoPlatformInterface) ClearDNSCache() {
	C.callClearDNSCache()
}

// ReadWIFIState returns the WIFI state
func (p *cgoPlatformInterface) ReadWIFIState() *libbox.WIFIState {
	cState := C.callReadWIFIState()
	if cState == nil {
		return nil
	}
	defer C.free(unsafe.Pointer(cState))

	var state WIFIState
	if err := json.Unmarshal([]byte(C.GoString(cState)), &state); err != nil {
		return nil
	}

	return libbox.NewWIFIState(state.SSID, state.BSSID)
}

// GetSystemProxyStatus returns the system proxy status
func (p *cgoPlatformInterface) GetSystemProxyStatus() *libbox.SystemProxyStatus {
	return &libbox.SystemProxyStatus{}
}

// SetSystemProxyEnabled sets the system proxy enabled state
func (p *cgoPlatformInterface) SetSystemProxyEnabled(enabled bool) error {
	return nil
}

// RestartService restarts the VPN service
func (p *cgoPlatformInterface) RestartService() error {
	result := C.callRestartService()
	if result != 0 {
		return errors.New("failed to restart service")
	}
	return nil
}

// PostServiceClose is called after service close
func (p *cgoPlatformInterface) PostServiceClose() {
	C.callPostServiceClose()
}

// SendNotification sends a notification
func (p *cgoPlatformInterface) SendNotification(notification *libbox.Notification) error {
	return nil
}

// LocalDNSTransport returns the local DNS transport
func (p *cgoPlatformInterface) LocalDNSTransport() libbox.LocalDNSTransport {
	return nil
}

// SystemCertificates returns the system certificates
func (p *cgoPlatformInterface) SystemCertificates() libbox.StringIterator {
	return nil
}

// sendEventToSwift sends an event to Swift if the callback is registered
func sendEventToSwift(event *utils.FlutterEvent) {
	eventData, err := json.Marshal(event)
	if err != nil {
		slog.Error("Error marshalling event for Swift:", "error", err)
		return
	}
	cEvent := C.CString(string(eventData))
	defer C.free(unsafe.Pointer(cEvent))
	C.callSwiftEventCallback(cEvent)
}

// startVPNWithPlatform starts the VPN using the registered platform callbacks
//
//export startVPNWithPlatform
func startVPNWithPlatform(_logDir, _dataDir, _locale *C.char) *C.char {
	slog.Debug("startVPNWithPlatform called")

	if !hasPlatformCallbacks() {
		return C.CString("error: platform callbacks not registered")
	}

	platform := getCgoPlatform()

	// Start VPN with the cgo platform interface
	sendStatusToPort(Connecting)
	err := vpn_tunnel.StartVPN(platform, &utils.Opts{
		DataDir: C.GoString(_dataDir),
		Locale:  C.GoString(_locale),
	})
	if err != nil {
		sendStatusToPort(Disconnected)
		return C.CString(err.Error())
	}
	sendStatusToPort(Connected)
	return C.CString("ok")
}

// connectToServerWithPlatform connects to a server using the registered platform callbacks
//
//export connectToServerWithPlatform
func connectToServerWithPlatform(_location, _tag, _logDir, _dataDir, _locale *C.char) *C.char {
	slog.Debug("connectToServerWithPlatform called")

	if !hasPlatformCallbacks() {
		return C.CString("error: platform callbacks not registered")
	}

	platform := getCgoPlatform()

	location := C.GoString(_location)
	tag := C.GoString(_tag)

	err := vpn_tunnel.ConnectToServer(location, tag, platform, &utils.Opts{
		DataDir: C.GoString(_dataDir),
		Locale:  C.GoString(_locale),
	})
	if err != nil {
		return SendError(err)
	}
	return C.CString("ok")
}
