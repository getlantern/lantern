package lanterncore

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/getlantern/radiance/account"
	"github.com/getlantern/radiance/common"
	"github.com/getlantern/radiance/common/env"
	"github.com/getlantern/radiance/common/settings"
	"github.com/getlantern/radiance/ipc"
	"github.com/getlantern/radiance/issue"
	"github.com/getlantern/radiance/servers"
	"github.com/getlantern/radiance/vpn"

	"github.com/getlantern/lantern/lantern-core/apps"
	privateserver "github.com/getlantern/lantern/lantern-core/private-server"
	"github.com/getlantern/lantern/lantern-core/utils"
	"github.com/getlantern/lantern/lantern-core/vpn_tunnel"
)

type EventType = string

const (
	EventTypeServerLocation EventType = "server-location"
	EventTypeConfig         EventType = "config"
	DefaultLogLevel                   = "trace"
)

// LanternCore wraps an IPC client and provides the interface expected by the FFI and mobile layers.
type LanternCore struct {
	client       *ipc.Client
	ctx          context.Context
	cancel       context.CancelFunc
	initOnce     sync.Once
	eventEmitter utils.FlutterEventEmitter
}

var (
	core      = &LanternCore{}
	initError atomic.Pointer[error]
)

type App interface {
	AvailableFeatures() []byte
	ReportIssue(email, issueType, description, device, model, logFilePath string) error
	IsRadianceConnected() bool
	IsVPNRunning() (bool, error)
	GetAvailableServers() []byte
	MyDeviceId() string
	GetServerByTagJSON(tag string) ([]byte, bool, error)
	GetSelectedServerJSON() ([]byte, error)
	GetSelectedServerTag() (string, error)
	GetAutoLocationJSON() ([]byte, error)
	CheckDaemonReachable() error
	PatchSettings(settings.Settings) error
	GetSettingsJSON() ([]byte, error)
	PatchEnvVars(map[string]string) (map[string]string, error)
	GetEnvVars() map[string]string
	RunOfflineURLTests() error
	UpdateConfig() error
	ReferralAttachment(referralCode string) (bool, error)
	UpdateLocale(locale string) error
	UpdateTelemetryConsent(consent bool) error
	IsTelemetryEnabled() bool
	IsOAuthLogin() bool
	GetOAuthProvider() string
	GetEnabledApps() (string, error)
}

type User interface {
	UserData() ([]byte, error)
	DataCapInfo() (string, error)
	FetchUserData() ([]byte, error)
	OAuthLoginUrl(provider string) (string, error)
	OAuthLoginCallback(oAuthToken string) ([]byte, error)

	Login(email, password string) ([]byte, error)
	SignUp(email, password string) error
	Logout(email string) ([]byte, error)
	StartRecoveryByEmail(email string) error
	ValidateChangeEmailCode(email, code string) error
	CompleteRecoveryByEmail(email, password, code string) error
	DeleteAccount(email, password string) ([]byte, error)
	RemoveDevice(deviceId string) (*account.LinkResponse, error)
	StartChangeEmail(newEmail, password string) error
	CompleteChangeEmail(email, password, code string) error
}

type PrivateServer interface {
	DigitalOceanPrivateServer(events utils.PrivateServerEventListener) error
	GoogleCloudPrivateServer(events utils.PrivateServerEventListener) error
	ValidateSession() error
	SelectAccount(account string) error
	SelectProject(project string) error
	CancelDeployment() error
	AddServerManagerInstance(ip, port, accessToken, tag string, events utils.PrivateServerEventListener) error
	InviteToServerManagerInstance(ip string, port string, accessToken string, inviteName string) (string, error)
	RevokeServerManagerInvite(ip string, port string, accessToken string, inviteName string) error
	StartDeployment(location, serverName string) error
	AddServersByURL(urls string, skipCertVerification bool) ([]byte, error)
	DeleteServer(tag string) error
	UpdatePrivateServerName(oldTag, newTag string) error
}

type Payment interface {
	StripeSubscription(email, planID string) (string, error)
	Plans(channel string) (string, error)
	StripeBillingPortalUrl() (string, error)
	AcknowledgeGooglePurchase(purchaseToken, planId string) (string, error)
	AcknowledgeApplePurchase(receipt, planII string) (string, error)
	PaymentRedirect(provider, planID, email string) (string, error)
	ActivationCode(email, resellerCode string) error
	SubscriptionPaymentRedirectURL(redirectBody account.PaymentRedirectData) (string, error)
	StripeSubscriptionPaymentRedirect(subscriptionType, planID, email string) (string, error)
}

type SplitTunnel interface {
	LoadInstalledApps(dataDir string) (string, error)
	IsSplitTunnelingEnabled() bool
	SetSplitTunnelingEnabled(bool) error
	AddSplitTunnelItem(filterType, item string) error
	AddSplitTunnelItems(items string) error
	RemoveSplitTunnelItem(filterType, item string) error
	RemoveSplitTunnelItems(items string) error
	GetSplitTunnelItems() (string, error)
	GetSplitTunnelItemsFor(filterType string) (string, error)
}

type Ads interface {
	SetBlockAdsEnabled(bool) error
	IsBlockAdsEnabled() bool
}

type SmartRouting interface {
	SetSmartRoutingEnabled(bool) error
	IsSmartRoutingEnabled() bool
}

type VPN interface {
	ConnectVPN(tag string) error
	SelectServer(tag string) error
	DisconnectVPN() error
	VPNStatus() (vpn.VPNStatus, error)
	VPNStatusEvents(ctx context.Context, callback func(evt vpn.StatusUpdateEvent)) error
}

type Core interface {
	App
	User
	Payment
	PrivateServer
	SplitTunnel
	Ads
	SmartRouting
	VPN
	Client() *ipc.Client
}

var _ Core = (*LanternCore)(nil)

func New(opts *utils.Opts, eventEmitter utils.FlutterEventEmitter) (Core, error) {
	if opts == nil || eventEmitter == nil {
		return nil, fmt.Errorf("opts and eventEmitter cannot be nil")
	}

	core.initOnce.Do(func() {
		if opts.LogLevel == "" {
			opts.LogLevel = DefaultLogLevel
		}
		slog.Debug("Initializing LanternCore with opts: ", "opts", opts)
		if err := core.initialize(opts, eventEmitter); err != nil {
			initError.Store(&err)
		}
	})
	if initError.Load() != nil {
		return nil, *initError.Load()
	}

	return core, nil
}

func (lc *LanternCore) initialize(opts *utils.Opts, eventEmitter utils.FlutterEventEmitter) error {
	// Wire up slog for the host process according to how the backend is
	// hosted on each platform:
	//
	//   - windows/linux: the UI is a separate process talking to a daemon
	//     over IPC, so it needs its own full common.Init.
	//   - darwin/ios: the UI shares its logDir with the tunnel extension,
	//     which is the process that called common.Init. Re-running it here
	//     would collide; instead we set up app-process-only logging into a
	//     distinct file so the two lumberjacks don't race on rotation.
	//   - android: the backend is embedded in the same process as the UI
	//     (see init_mobile.go), and Mobile.SetupRadiance has already called
	//     common.Init by the time we reach here. Fall through with no
	//     additional setup.
	switch runtime.GOOS {
	case "windows", "linux":
		if err := common.Init(opts.DataDir, opts.LogDir, opts.LogLevel); err != nil {
			return fmt.Errorf("common.Init: %w", err)
		}
	case "darwin", "ios":
		setupAppLogging(opts.LogDir, opts.LogLevel)
	}
	slog.Debug("Starting LanternCore initialization")

	if opts.Env == "stage" || opts.Env == "staging" {
		slog.Debug("Setting staging environment")
		env.SetStagingEnv()
	}

	ctx, cancel := context.WithCancel(context.Background())
	client, err := createClient(ctx, opts)
	if err != nil {
		cancel()
		return fmt.Errorf("failed to create IPC client: %w", err)
	}

	lc.client = client
	lc.ctx = ctx
	lc.cancel = cancel
	lc.eventEmitter = eventEmitter

	go lc.listenAutoSelectedEvents()
	go lc.listenConfigEvents()
	go lc.listenDataCapEvents()
	go lc.fetchUserDataIfNeeded()

	slog.Debug("LanternCore initialized successfully")
	return nil
}

func (lc *LanternCore) Client() *ipc.Client {
	return lc.client
}

// notifyFlutter sends an event to the Flutter frontend via the event emitter.
func (lc *LanternCore) notifyFlutter(event EventType, message string) {
	slog.Debug("Notifying Flutter")
	lc.eventEmitter.SendEvent(&utils.FlutterEvent{
		Type:    string(event),
		Message: message,
	})
}

// fetchUserDataIfNeeded pulls fresh user data from the server at startup
func (lc *LanternCore) fetchUserDataIfNeeded() {
	raw := lc.settings()[settings.UserIDKey]
	userID := userIDAsInt64(raw)
	if userID == 0 {
		slog.Debug("Skipping startup user-data fetch: no user ID set", "raw", raw)
		return
	}
	if _, err := lc.client.FetchUserData(lc.ctx); err != nil {
		slog.Error("Startup user-data fetch failed", "error", err)
		return
	}
	slog.Debug("Startup user-data fetch succeeded", "userID", userID)
}

// userIDAsInt64 normalizes the radiance UserIDKey value across the storage
// types it can have: int64 (in-process), float64 (after JSON IPC round-trip),
// int (defensive), or a decimal string (mobile.go purchase flow). Returns 0
// for any unrecognized type so the caller treats the user as anonymous.
func userIDAsInt64(v any) int64 {
	switch x := v.(type) {
	case int64:
		return x
	case float64:
		return int64(x)
	case int:
		return int64(x)
	case string:
		n, _ := strconv.ParseInt(x, 10, 64)
		return n
	}
	return 0
}

// listenAutoSelectedEvents listens for auto-selected server changes from the IPC client and forwards
// them to Flutter. Blocks until lc.ctx is cancelled.
func (lc *LanternCore) listenAutoSelectedEvents() {
	err := lc.client.AutoSelectedEvents(lc.ctx, func(evt vpn.AutoSelectedEvent) {
		server, found, err := lc.client.GetServerByTag(lc.ctx, evt.Selected)
		if err != nil || !found {
			slog.Error("no server found with tag", "tag", evt.Selected, "error", err)
			return
		}
		jsonBytes, err := json.Marshal(server)
		if err != nil {
			slog.Error("Error marshalling server location", "error", err)
			return
		}
		slog.Debug("Auto location server:", "server", string(jsonBytes))
		lc.notifyFlutter(EventTypeServerLocation, string(jsonBytes))
	})
	if err != nil && lc.ctx.Err() == nil {
		slog.Error("auto-selected event stream exited unexpectedly", "error", err)
	}
}

// listenConfigEvents listens for config updates from the IPC client and notifies Flutter when they
// occur. Blocks until lc.ctx is cancelled.
func (lc *LanternCore) listenConfigEvents() {
	err := lc.client.ConfigEvents(lc.ctx, func() {
		slog.Debug("Config updated, notifying Flutter")
		lc.notifyFlutter(EventTypeConfig, "")
	})
	if err != nil && lc.ctx.Err() == nil {
		slog.Error("config event stream exited unexpectedly", "error", err)
	}
}

// listenDataCapEvents listens for DataCapInfo updates from the IPC client and forwards them to Flutter.
// Blocks until lc.ctx is cancelled.
func (lc *LanternCore) listenDataCapEvents() {
	err := lc.client.DataCapStream(lc.ctx, func(info account.DataCapInfo) {
		jsonBytes, err := json.Marshal(info)
		if err != nil {
			slog.Error("Error marshalling DataCap event", "error", err)
			return
		}
		lc.notifyFlutter("data-cap-event", string(jsonBytes))
	})
	if err != nil && lc.ctx.Err() == nil {
		slog.Error("datacap event stream exited unexpectedly", "error", err)
	}
}

/////////////////
//     VPN     //
/////////////////

// Per-call IPC timeouts. These bound the worst case if lanternd is hung
// (pipe open, no replies). They're long enough to never fire during normal
// operation — the connect path involves real DNS / TLS / sing-box bring-up
// that can take many seconds, while a /vpn/status query should be near-
// instant — but tight enough that a stuck daemon surfaces as a UI error
// instead of an indefinite spinner. The dialer already has a 10 s connect
// timeout (radiance/ipc/conn_windows.go), so these only matter once the
// pipe is established.
const (
	ipcConnectTimeout     = 60 * time.Second
	ipcStateChangeTimeout = 30 * time.Second
	ipcStatusTimeout      = 10 * time.Second
)

// ConnectVPN routes a connect request through vpn_tunnel.ConnectToServer,
// which picks between /vpn/connect (fresh tunnel) and /server/selected
// (live-tunnel outbound swap) based on VPNStatus. This is load-bearing for
// the Smart-from-connected flow: Jigar's onSmartLocation rewrite
// (server_selection.dart) routes "switch back to auto" through
// startVPN(force: true) → ffi.go:startVPN → c.ConnectVPN(""). Without the
// dispatch the call 500s with ErrTunnelAlreadyConnected from
// radiance/vpn/vpn.go:130 and the user sees a snackbar.
//
// Fixes getlantern/engineering#3291 issue 3.
func (lc *LanternCore) ConnectVPN(tag string) error {
	ctx, cancel := context.WithTimeout(lc.ctx, ipcConnectTimeout)
	defer cancel()
	return vpn_tunnel.ConnectToServer(ctx, lc.client, tag)
}

func (lc *LanternCore) SelectServer(tag string) error {
	ctx, cancel := context.WithTimeout(lc.ctx, ipcStateChangeTimeout)
	defer cancel()
	return lc.client.SelectServer(ctx, tag)
}

func (lc *LanternCore) DisconnectVPN() error {
	ctx, cancel := context.WithTimeout(lc.ctx, ipcStateChangeTimeout)
	defer cancel()
	return lc.client.DisconnectVPN(ctx)
}

func (lc *LanternCore) VPNStatus() (vpn.VPNStatus, error) {
	ctx, cancel := context.WithTimeout(lc.ctx, ipcStatusTimeout)
	defer cancel()
	return lc.client.VPNStatus(ctx)
}

func (lc *LanternCore) IsVPNRunning() (bool, error) {
	status, err := lc.VPNStatus()
	if err != nil {
		return false, err
	}
	return status == vpn.Connected, nil
}

func (lc *LanternCore) VPNStatusEvents(ctx context.Context, callback func(evt vpn.StatusUpdateEvent)) error {
	return lc.client.VPNStatusEvents(ctx, callback)
}

/////////////////
//  Settings   //
/////////////////

// settings returns the current settings from radiance.
func (lc *LanternCore) settings() settings.Settings {
	s, err := lc.client.Settings(lc.ctx)
	if err != nil {
		slog.Error("Error fetching settings", "error", err)
		return settings.Settings{}
	}
	return s
}

func (lc *LanternCore) UpdateTelemetryConsent(consent bool) error {
	return lc.client.EnableTelemetry(lc.ctx, consent)
}

func (lc *LanternCore) SetBlockAdsEnabled(enabled bool) error {
	return lc.client.EnableAdBlocking(lc.ctx, enabled)
}

func (lc *LanternCore) IsBlockAdsEnabled() bool {
	b, _ := lc.settings()[settings.AdBlockKey].(bool)
	return b
}

func (lc *LanternCore) SetSmartRoutingEnabled(enabled bool) error {
	return lc.client.EnableSmartRouting(lc.ctx, enabled)
}

func (lc *LanternCore) IsSmartRoutingEnabled() bool {
	b, _ := lc.settings()[settings.SmartRoutingKey].(bool)
	return b
}

func (lc *LanternCore) IsTelemetryEnabled() bool {
	b, _ := lc.settings()[settings.TelemetryKey].(bool)
	return b
}

func (lc *LanternCore) IsOAuthLogin() bool {
	b, _ := lc.settings()[settings.OAuthLoginKey].(bool)
	return b
}

func (lc *LanternCore) GetOAuthProvider() string {
	v, _ := lc.settings()[settings.OAuthProviderKey].(string)
	return v
}

func (lc *LanternCore) IsRadianceConnected() bool {
	return lc.client != nil
}

func (lc *LanternCore) MyDeviceId() string {
	v, _ := lc.settings()[settings.DeviceIDKey].(string)
	return v
}

func (lc *LanternCore) UpdateLocale(locale string) error {
	_, err := lc.client.PatchSettings(lc.ctx, settings.Settings{settings.LocaleKey: locale})
	return err
}

func (lc *LanternCore) AvailableFeatures() []byte {
	features, err := lc.client.Features(lc.ctx)
	if err != nil {
		slog.Error("Error getting features", "error", err)
		return nil
	}
	jsonBytes, err := json.Marshal(features)
	if err != nil {
		slog.Error("Error marshalling features", "error", err)
		return nil
	}
	return jsonBytes
}

func (lc *LanternCore) GetAvailableServers() []byte {
	data, err := lc.client.ServersJSON(lc.ctx)
	if err != nil {
		slog.Error("Error getting servers", "error", err)
		return nil
	}
	return data
}

func (lc *LanternCore) GetServerByTagJSON(tag string) ([]byte, bool, error) {
	return lc.client.GetServerByTagJSON(lc.ctx, tag)
}

func (lc *LanternCore) GetSelectedServerJSON() ([]byte, error) {
	return lc.client.SelectedServerJSON(lc.ctx)
}

func (lc *LanternCore) GetSelectedServerTag() (string, error) {
	server, exists, err := lc.client.SelectedServer(lc.ctx)
	if err != nil {
		return "", err
	}
	if !exists {
		return "", nil
	}
	return server.Tag, nil
}

func (lc *LanternCore) GetAutoLocationJSON() ([]byte, error) {
	server, err := lc.client.AutoSelected(lc.ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to get auto location: %w", err)
	}
	return json.Marshal(server)
}

func (lc *LanternCore) CheckDaemonReachable() error {
	ctx, cancel := context.WithTimeout(context.Background(), 300*time.Millisecond)
	defer cancel()
	_, err := lc.client.VPNStatus(ctx)
	return err
}

func (lc *LanternCore) PatchSettings(s settings.Settings) error {
	_, err := lc.client.PatchSettings(lc.ctx, s)
	return err
}

func (lc *LanternCore) GetSettingsJSON() ([]byte, error) {
	s, err := lc.client.Settings(lc.ctx)
	if err != nil {
		return nil, err
	}
	return json.Marshal(s)
}

func (lc *LanternCore) PatchEnvVars(updates map[string]string) (map[string]string, error) {
	return lc.client.PatchEnvVars(lc.ctx, updates)
}

// GetEnvVars returns the daemon's in-memory env vars. Uses an empty PATCH
// because ipc.Client exposes no dedicated GET; the daemon returns the full
// env map on both GET and PATCH.
func (lc *LanternCore) GetEnvVars() map[string]string {
	vars, err := lc.client.PatchEnvVars(lc.ctx, map[string]string{})
	if err != nil {
		slog.Error("Error fetching env vars", "error", err)
		return nil
	}
	return vars
}

func (lc *LanternCore) RunOfflineURLTests() error {
	return lc.client.RunOfflineURLTests(lc.ctx)
}

func (lc *LanternCore) UpdateConfig() error {
	return lc.client.UpdateConfig(lc.ctx)
}

/////////////////
// Split Tunnel //
/////////////////

// TODO: ??? not sure what to do about this one. it can't access dataDir
func (lc *LanternCore) LoadInstalledApps(dataDir string) (string, error) {
	appsList := []*apps.AppData{}
	apps.LoadInstalledApps(dataDir, func(a ...*apps.AppData) error {
		appsList = append(appsList, a...)
		return nil
	})
	b, err := json.Marshal(appsList)
	if err != nil {
		return "", err
	}
	return string(b), nil
}

func (lc *LanternCore) SetSplitTunnelingEnabled(enabled bool) error {
	return lc.client.EnableSplitTunneling(lc.ctx, enabled)
}

func (lc *LanternCore) IsSplitTunnelingEnabled() bool {
	b, _ := lc.settings()[settings.SplitTunnelKey].(bool)
	return b
}

func (lc *LanternCore) AddSplitTunnelItem(filterType, item string) error {
	filter := filterFromTypeAndItems(filterType, []string{item})
	return lc.client.AddSplitTunnelItems(lc.ctx, filter)
}

func (lc *LanternCore) AddSplitTunnelItems(items string) error {
	split := splitCSVClean(items)
	filter := platformFilter(split)
	return lc.client.AddSplitTunnelItems(lc.ctx, filter)
}

func (lc *LanternCore) RemoveSplitTunnelItem(filterType, item string) error {
	filter := filterFromTypeAndItems(filterType, []string{item})
	return lc.client.RemoveSplitTunnelItems(lc.ctx, filter)
}

func (lc *LanternCore) RemoveSplitTunnelItems(items string) error {
	split := splitCSVClean(items)
	filter := platformFilter(split)
	return lc.client.RemoveSplitTunnelItems(lc.ctx, filter)
}

func (lc *LanternCore) GetSplitTunnelItems() (string, error) {
	filter, err := lc.client.SplitTunnelFilters(lc.ctx)
	if err != nil {
		return "{}", nil
	}
	b, err := json.Marshal(filter)
	if err != nil {
		return "{}", nil
	}
	return string(b), nil
}

func (lc *LanternCore) GetSplitTunnelItemsFor(filterType string) (string, error) {
	filter, err := lc.client.SplitTunnelFilters(lc.ctx)
	if err != nil {
		return "", err
	}
	items := itemsForType(filter, filterType)
	b, err := json.Marshal(items)
	if err != nil {
		return "", err
	}
	return string(b), nil
}

func (lc *LanternCore) GetEnabledApps() (string, error) {
	filter, err := lc.client.SplitTunnelFilters(lc.ctx)
	if err != nil {
		return "", err
	}
	// Initialize as empty slice so json.Marshal emits "[]" rather than
	// "null" when no items are enabled — Dart's jsonDecode("null") returns
	// null and the receiver does `as List`, which throws. Was the actual
	// cause of "Failed to fetch installed apps" empty list in
	// Freshdesk #173774 / #173778 / #173826.
	enabledApps := []string{}
	enabledApps = append(enabledApps, filter.ProcessPath...)
	enabledApps = append(enabledApps, filter.ProcessPathRegex...)
	enabledApps = append(enabledApps, filter.PackageName...)
	b, err := json.Marshal(enabledApps)
	if err != nil {
		return "", err
	}
	return string(b), nil
}

/////////////////
// Issue Report //
/////////////////

func (lc *LanternCore) ReportIssue(email, issueType, description, device, model, logFilePath string) error {
	it := parseIssueType(issueType)
	var attachments []string
	// Windows + Linux have separate UI and daemon logDirs, so the daemon's
	// own archive glob misses UI-process logs — pass them through as paths.
	// Mobile + macOS already share the directory; no pass-through needed.
	// Relies on the UI logDir being readable by the daemon (SYSTEM on
	// Windows); %PUBLIC%\Lantern\logs is chosen for that.
	if runtime.GOOS == "windows" || runtime.GOOS == "linux" {
		attachments = collectLocalLogs(settings.GetString(settings.LogPathKey))
	}
	if logFilePath != "" {
		attachments = append(attachments, logFilePath)
	}
	return lc.client.ReportIssue(lc.ctx, it, description, email, attachments)
}

// collectLocalLogs returns every *.log directly under dir, with paths shaped
// however filepath.Glob returns them (relative if dir is relative; the
// daemon-side ReportIssue path on windows/linux passes the absolute
// settings.LogPathKey so this is absolute in practice).
//
// Files we can't os.Stat from the UI process are dropped. That's a
// best-effort screen, not a guarantee — the daemon runs as SYSTEM on
// Windows and may be able to read files this process can't, and vice
// versa. The drop avoids attaching obviously-broken paths to issue
// reports; the daemon's own readability check is authoritative.
func collectLocalLogs(dir string) []string {
	if dir == "" {
		return nil
	}
	matches, err := filepath.Glob(filepath.Join(dir, "*.log"))
	if err != nil {
		slog.Warn("ReportIssue: unable to glob local logs", "dir", dir, "err", err)
		return nil
	}
	out := matches[:0]
	for _, p := range matches {
		if _, err := os.Stat(p); err != nil {
			slog.Warn("ReportIssue: skipping log (unreadable from this process)", "path", p, "err", err)
			continue
		}
		out = append(out, p)
	}
	return out
}

func parseIssueType(s string) issue.IssueType {
	switch strings.ToLower(s) {
	case "cannot_complete_purchase":
		return issue.CannotCompletePurchase
	case "cannot_sign_in":
		return issue.CannotSignIn
	case "spinner_loads_endlessly":
		return issue.SpinnerLoadsEndlessly
	case "cannot_access_blocked_sites":
		return issue.CannotAccessBlockedSites
	case "slow":
		return issue.Slow
	case "cannot_link_device":
		return issue.CannotLinkDevice
	case "application_crashes":
		return issue.ApplicationCrashes
	case "update_fails":
		return issue.UpdateFails
	default:
		return issue.Other
	}
}

/////////////////
//   Account   //
/////////////////

func (lc *LanternCore) DataCapInfo() (string, error) {
	info, err := lc.client.DataCapInfo(lc.ctx)
	if err != nil {
		return "", err
	}
	jsonBytes, err := json.Marshal(info)
	if err != nil {
		return "", fmt.Errorf("error marshalling DataCapInfo: %w", err)
	}
	return string(jsonBytes), nil
}

func (lc *LanternCore) UserData() ([]byte, error) {
	userData, err := lc.client.UserData(lc.ctx)
	if err != nil {
		return nil, err
	}
	return json.Marshal(userData)
}

func (lc *LanternCore) FetchUserData() ([]byte, error) {
	userData, err := lc.client.FetchUserData(lc.ctx)
	if err != nil {
		return nil, err
	}
	return json.Marshal(userData)
}

func (lc *LanternCore) OAuthLoginUrl(provider string) (string, error) {
	return lc.client.OAuthLoginURL(lc.ctx, provider)
}

func (lc *LanternCore) OAuthLoginCallback(oAuthToken string) ([]byte, error) {
	userData, err := lc.client.OAuthLoginCallback(lc.ctx, oAuthToken)
	if err != nil {
		return nil, err
	}
	return json.Marshal(userData)
}

func (lc *LanternCore) Login(email, password string) ([]byte, error) {
	userData, err := lc.client.Login(lc.ctx, email, password)
	if err != nil {
		return nil, err
	}
	return json.Marshal(userData)
}

func (lc *LanternCore) SignUp(email, password string) error {
	_, _, err := lc.client.SignUp(lc.ctx, email, password)
	return err
}

func (lc *LanternCore) Logout(email string) ([]byte, error) {
	userData, err := lc.client.Logout(lc.ctx, email)
	if err != nil {
		return nil, err
	}
	return json.Marshal(userData)
}

func (lc *LanternCore) StartRecoveryByEmail(email string) error {
	return lc.client.StartRecoveryByEmail(lc.ctx, email)
}

func (lc *LanternCore) ValidateChangeEmailCode(email, code string) error {
	return lc.client.ValidateEmailRecoveryCode(lc.ctx, email, code)
}

func (lc *LanternCore) CompleteRecoveryByEmail(email, password, code string) error {
	return lc.client.CompleteRecoveryByEmail(lc.ctx, email, password, code)
}

func (lc *LanternCore) DeleteAccount(email, password string) ([]byte, error) {
	userData, err := lc.client.DeleteAccount(lc.ctx, email, password)
	if err != nil {
		return nil, err
	}
	return json.Marshal(userData)
}

func (lc *LanternCore) RemoveDevice(deviceID string) (*account.LinkResponse, error) {
	return lc.client.RemoveDevice(lc.ctx, deviceID)
}

func (lc *LanternCore) StartChangeEmail(newEmail, password string) error {
	return lc.client.StartChangeEmail(lc.ctx, newEmail, password)
}

func (lc *LanternCore) CompleteChangeEmail(email, password, code string) error {
	return lc.client.CompleteChangeEmail(lc.ctx, email, password, code)
}

func (lc *LanternCore) ReferralAttachment(referralCode string) (bool, error) {
	return lc.client.ReferralAttach(lc.ctx, referralCode)
}

/////////////////
//  Payments   //
/////////////////

func (lc *LanternCore) StripeSubscription(email, planID string) (string, error) {
	return lc.client.NewStripeSubscription(lc.ctx, email, planID)
}

func (lc *LanternCore) Plans(channel string) (string, error) {
	return lc.client.SubscriptionPlans(lc.ctx, channel)
}

func (lc *LanternCore) StripeBillingPortalUrl() (string, error) {
	return lc.client.StripeBillingPortalURL(lc.ctx)
}

func (lc *LanternCore) AcknowledgeGooglePurchase(purchaseToken, planId string) (string, error) {
	params := map[string]string{
		"purchaseToken": purchaseToken,
		"planId":        planId,
	}
	return lc.client.VerifySubscription(lc.ctx, account.GoogleService, params)
}

func (lc *LanternCore) AcknowledgeApplePurchase(receipt, planII string) (string, error) {
	params := map[string]string{
		"receipt": receipt,
		"planId":  planII,
	}
	return lc.client.VerifySubscription(lc.ctx, account.AppleService, params)
}

func (lc *LanternCore) SubscriptionPaymentRedirectURL(redirectBody account.PaymentRedirectData) (string, error) {
	return lc.client.SubscriptionPaymentRedirectURL(lc.ctx, redirectBody)
}

func (lc *LanternCore) StripeSubscriptionPaymentRedirect(subscriptionType, planID, email string) (string, error) {
	deviceID := lc.MyDeviceId()
	redirectBody := account.PaymentRedirectData{
		Provider:    "stripe",
		Plan:        planID,
		DeviceName:  deviceID,
		Email:       email,
		BillingType: account.SubscriptionType(subscriptionType),
	}
	return lc.SubscriptionPaymentRedirectURL(redirectBody)
}

func (lc *LanternCore) PaymentRedirect(provider, planId, email string) (string, error) {
	deviceName := lc.MyDeviceId()
	body := account.PaymentRedirectData{
		Provider:   provider,
		Plan:       planId,
		DeviceName: deviceName,
		Email:      email,
	}
	return lc.client.PaymentRedirect(lc.ctx, body)
}

func (lc *LanternCore) ActivationCode(email, resellerCode string) error {
	purchase, err := lc.client.ActivationCode(lc.ctx, email, resellerCode)
	if err != nil {
		return fmt.Errorf("error getting activation code: %w", err)
	}
	if purchase.Status != "ok" {
		return fmt.Errorf("activation code failed: %s", purchase.Status)
	}
	return nil
}

/////////////////////
// Private Servers //
/////////////////////

func (lc *LanternCore) DigitalOceanPrivateServer(events utils.PrivateServerEventListener) error {
	return privateserver.StartDigitalOceanPrivateServerFlow(events, lc.client)
}

func (lc *LanternCore) GoogleCloudPrivateServer(events utils.PrivateServerEventListener) error {
	return privateserver.StartGoogleCloudPrivateServerFlow(events, lc.client)
}

func (lc *LanternCore) ValidateSession() error {
	return privateserver.ValidateSession(context.Background())
}

func (lc *LanternCore) SelectAccount(account string) error {
	return privateserver.SelectAccount(account)
}

func (lc *LanternCore) SelectProject(project string) error {
	return privateserver.SelectProject(project)
}

func (lc *LanternCore) StartDeployment(location, serverName string) error {
	return privateserver.StartDeployment(location, serverName)
}

func (lc *LanternCore) CancelDeployment() error {
	return privateserver.CancelDeployment()
}

func (lc *LanternCore) AddServerManagerInstance(ip, port, accessToken, tag string, events utils.PrivateServerEventListener) error {
	return privateserver.AddServerManually(ip, port, accessToken, tag, lc.client, events)
}

func (lc *LanternCore) InviteToServerManagerInstance(ip, port, accessToken, inviteName string) (string, error) {
	portInt, err := parsePort(port)
	if err != nil {
		return "", err
	}
	return lc.client.InviteToPrivateServer(lc.ctx, ip, portInt, accessToken, inviteName)
}

func (lc *LanternCore) RevokeServerManagerInvite(ip, port, accessToken, inviteName string) error {
	portInt, err := parsePort(port)
	if err != nil {
		return err
	}
	return lc.client.RevokePrivateServerInvite(lc.ctx, ip, portInt, accessToken, inviteName)
}

func (lc *LanternCore) DeleteServer(tag string) error {
	return lc.client.RemoveServers(lc.ctx, []string{tag})
}

func (lc *LanternCore) UpdatePrivateServerName(oldTag, newTag string) error {
	if oldTag == "" || newTag == "" {
		return fmt.Errorf("old and new server names must be non-empty")
	}
	if oldTag == newTag {
		return nil
	}

	// Find source server
	source, exists, err := lc.client.GetServerByTag(lc.ctx, oldTag)
	if err != nil {
		return fmt.Errorf("failed to get server %q: %w", oldTag, err)
	}
	if !exists {
		return fmt.Errorf("server with tag %q not found", oldTag)
	}

	// Check new tag doesn't collide
	_, collision, _ := lc.client.GetServerByTag(lc.ctx, newTag)
	if collision {
		return fmt.Errorf("server with tag %q already exists", newTag)
	}

	// Remove old, add renamed copy
	if err := lc.client.RemoveServers(lc.ctx, []string{oldTag}); err != nil {
		return fmt.Errorf("failed to remove old server %q: %w", oldTag, err)
	}
	source.Tag = newTag
	list := servers.ServerList{Servers: []*servers.Server{source}}
	if err := lc.client.AddServers(lc.ctx, list); err != nil {
		return fmt.Errorf("failed to add renamed server %q: %w", newTag, err)
	}
	return nil
}

func (lc *LanternCore) AddServersByURL(urls string, skipCertVerification bool) ([]byte, error) {
	urlList := strings.Split(urls, ",")
	for i, u := range urlList {
		urlList[i] = strings.TrimSpace(u)
	}

	tags, err := lc.client.AddServersByURL(lc.ctx, urlList, skipCertVerification)
	if err != nil {
		return nil, err
	}

	return json.Marshal(tags)
}

/////////////////
//  Helpers    //
/////////////////

func parsePort(port string) (int, error) {
	portInt := 0
	_, err := fmt.Sscanf(port, "%d", &portInt)
	if err != nil {
		return 0, fmt.Errorf("invalid port %q: %w", port, err)
	}
	if portInt <= 0 || portInt > 65535 {
		return 0, fmt.Errorf("invalid port %d: must be between 1 and 65535", portInt)
	}
	return portInt, nil
}

func splitCSVClean(s string) []string {
	raw := strings.Split(s, ",")
	out := make([]string, 0, len(raw))
	seen := make(map[string]struct{}, len(raw))
	for _, it := range raw {
		it = strings.TrimSpace(it)
		it = strings.Trim(it, `"`)
		if it == "" {
			continue
		}
		if common.IsWindows() {
			it = strings.ToLower(it)
		}
		if _, ok := seen[it]; ok {
			continue
		}
		seen[it] = struct{}{}
		out = append(out, it)
	}
	return out
}

func platformFilter(items []string) vpn.SplitTunnelFilter {
	if common.IsMacOS() {
		return vpn.SplitTunnelFilter{ProcessPathRegex: items}
	} else if common.IsWindows() {
		return vpn.SplitTunnelFilter{ProcessPath: items}
	}
	return vpn.SplitTunnelFilter{PackageName: items}
}

func filterFromTypeAndItems(filterType string, items []string) vpn.SplitTunnelFilter {
	switch filterType {
	case vpn.TypeDomain:
		return vpn.SplitTunnelFilter{Domain: items}
	case vpn.TypeDomainSuffix:
		return vpn.SplitTunnelFilter{DomainSuffix: items}
	case vpn.TypeDomainKeyword:
		return vpn.SplitTunnelFilter{DomainKeyword: items}
	case vpn.TypeDomainRegex:
		return vpn.SplitTunnelFilter{DomainRegex: items}
	case vpn.TypeProcessName:
		return vpn.SplitTunnelFilter{ProcessName: items}
	case vpn.TypeProcessPath:
		return vpn.SplitTunnelFilter{ProcessPath: items}
	case vpn.TypeProcessPathRegex:
		return vpn.SplitTunnelFilter{ProcessPathRegex: items}
	case vpn.TypePackageName:
		return vpn.SplitTunnelFilter{PackageName: items}
	default:
		return vpn.SplitTunnelFilter{}
	}
}

func itemsForType(filter vpn.SplitTunnelFilter, filterType string) []string {
	switch filterType {
	case vpn.TypeDomain:
		return filter.Domain
	case vpn.TypeDomainSuffix:
		return filter.DomainSuffix
	case vpn.TypeDomainKeyword:
		return filter.DomainKeyword
	case vpn.TypeDomainRegex:
		return filter.DomainRegex
	case vpn.TypeProcessName:
		return filter.ProcessName
	case vpn.TypeProcessPath:
		return filter.ProcessPath
	case vpn.TypeProcessPathRegex:
		return filter.ProcessPathRegex
	case vpn.TypePackageName:
		return filter.PackageName
	default:
		return nil
	}
}
