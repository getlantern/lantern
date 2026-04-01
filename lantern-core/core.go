package lanterncore

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"

	"github.com/getlantern/radiance"
	"github.com/getlantern/radiance/api"
	"github.com/getlantern/radiance/common"
	"github.com/getlantern/radiance/common/env"
	"github.com/getlantern/radiance/common/settings"
	"github.com/getlantern/radiance/config"
	"github.com/getlantern/radiance/events"
	"github.com/getlantern/radiance/issue"
	"github.com/getlantern/radiance/servers"
	"github.com/getlantern/radiance/vpn"

	"github.com/getlantern/lantern/lantern-core/apps"
	privateserver "github.com/getlantern/lantern/lantern-core/private-server"
	"github.com/getlantern/lantern/lantern-core/utils"
)

type EventType = string

const (
	EventTypeConfig         EventType = "config"
	EventTypeServerLocation EventType = "server-location"
	DefaultLogLevel                   = "trace"

	plansCacheFile = "plans-cache.json"
)

// LanternCore is the main structure accessing the Lantern backend.
type LanternCore struct {
	rad           *radiance.Radiance
	splitTunnel   *vpn.SplitTunnel
	serverManager *servers.Manager
	apiClient     *api.APIClient
	initOnce      sync.Once
	eventEmitter  utils.FlutterEventEmitter
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
	ReferralAttachment(referralCode string) (bool, error)
	UpdateLocale(locale string) error
	StartBackgroundListeners()
	StopBackgroundListeners()
	UpdateTelemetryConsent(consent bool) error
	GetAppDataDir() string
	GetEnabledApps() (string, error)
}

type User interface {
	UserData() ([]byte, error)
	DataCapInfo() (string, error)
	DataCapStream(ctx context.Context) error
	FetchUserData() ([]byte, error)
	OAuthLoginUrl(provider string) (string, error)
	OAuthLoginCallback(oAuthToken string) ([]byte, error)

	Login(email, password string) ([]byte, error)
	SignUp(email, password string) error
	Logout(email string) ([]byte, error)
	StartRecoveryByEmail(email string) error
	ValidateChangeEmailCode(email, code string) error
	CompleteRecoveryByEmail(email, password, code string) error
	DeleteAccount(email, password string, isOAuthUser bool) ([]byte, error)
	RemoveDevice(deviceId string) (*api.LinkResponse, error)
	//Change email
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
	AddServerBasedOnURLs(urls string, skipCertVerification bool, serverName string) error
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
	SubscriptionPaymentRedirectURL(redirectBody api.PaymentRedirectData) (string, error)
	StripeSubscriptionPaymentRedirect(subscriptionType, planID, email string) (string, error)
}

type SplitTunnel interface {
	LoadInstalledApps(dataDir string) (string, error)
	IsSplitTunnelingEnabled() bool
	SetSplitTunnelingEnabled(bool)
	AddSplitTunnelItem(filterType, item string) error
	AddSplitTunnelItems(items string) error
	RemoveSplitTunnelItem(filterType, item string) error
	RemoveSplitTunnelItems(items string) error
	GetSplitTunnelStateJSON() (string, error)
	GetSplitTunnelItems(filterType string) (string, error)
}

type Ads interface {
	SetBlockAdsEnabled(bool) error
	IsBlockAdsEnabled() bool
}

type SmartRouting interface {
	SetSmartRoutingEnabled(bool) error
	IsSmartRoutingEnabled() bool
}

type Core interface {
	App
	User
	Payment
	PrivateServer
	SplitTunnel
	Ads
	SmartRouting
}

// Make sure LanternCore implements the Core interface
var _ Core = (*LanternCore)(nil)

func New(opts *utils.Opts, eventEmitter utils.FlutterEventEmitter) (Core, error) {
	if opts == nil || eventEmitter == nil {
		return nil, fmt.Errorf("opts and eventEmitter cannot be nil")
	}

	// This isn't ideal, but currently on Android and maybe other platforms
	// there are multiple places that try to initialize the backend, so we
	// need to ensure it's only done once.
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
	slog.Debug("Starting LanternCore initialization")
	// Set the environment before initializing Radiance so that common.Stage()/Prod()/Dev()
	// pick up the correct value during initialization.
	if opts.Env == "stage" || opts.Env == "staging" {
		slog.Debug("Setting staging environment")
		env.SetStagingEnv()
	}
	var radErr error
	if lc.rad, radErr = radiance.NewRadiance(radiance.Options{
		LogDir:           opts.LogDir,
		DataDir:          opts.DataDir,
		DeviceID:         opts.Deviceid,
		LogLevel:         opts.LogLevel,
		Locale:           opts.Locale,
		TelemetryConsent: opts.TelemetryConsent,
	}); radErr != nil {
		return fmt.Errorf("failed to create Radiance: %w", radErr)
	}
	slog.Debug("Paths:", "logs", settings.GetString(settings.LogPathKey), "data", settings.GetString(settings.DataPathKey))

	fixStaleSettingsFilePath(opts.DataDir)

	var sthErr error
	if lc.splitTunnel, sthErr = vpn.NewSplitTunnelHandler(); sthErr != nil {
		return fmt.Errorf("unable to create split tunnel handler: %v", sthErr)
	}

	lc.serverManager = lc.rad.ServerManager()
	lc.apiClient = lc.rad.APIHandler()
	lc.eventEmitter = eventEmitter

	// Listen for config updates and notify Flutter
	events.Subscribe(func(evt config.NewConfigEvent) {
		core.notifyFlutter(EventTypeConfig, "Config is fetched/updated")
	})

	lc.listeningServerLocationChanges()
	lc.listeningDataCapChanges()
	slog.Debug("LanternCore initialized successfully")

	// If we have a legacy user ID, fetch user data
	if settings.GetInt64(settings.UserIDKey) != 0 {
		userData, _ := core.FetchUserData()
		slog.Debug("Fetched user data", "data", string(userData))
	}

	return nil
}

// Listen for server location changes and notify Flutter
func (lc *LanternCore) listeningServerLocationChanges() {
	events.Subscribe(func(evt vpn.AutoSelectionsEvent) {
		tag := evt.Selections.Lantern
		servers, ok := lc.serverManager.GetServerByTag(tag)
		if !ok {
			slog.Error("no server found with tag", "tag", tag)
			return
		}
		jsonBytes, err := json.Marshal(servers)
		if err != nil {
			slog.Error("Error marshalling server location", "error", err)
			return
		}
		stringBody := string(jsonBytes)
		slog.Debug("Auto location server:", "server", stringBody)
		lc.notifyFlutter(EventTypeServerLocation, stringBody)
	})
}
func (lc *LanternCore) listeningDataCapChanges() {
	events.Subscribe(func(evt api.DataCapChangeEvent) {
		dataCapResponse := evt.DataCapUsageResponse
		jsonBytes, err := json.Marshal(dataCapResponse)
		if err != nil {
			slog.Error("Error marshalling DataCap event", "error", err)
			return
		}
		stringBody := string(jsonBytes)
		slog.Debug("DataCap event:", "event", stringBody)
		lc.notifyFlutter("data-cap-event", stringBody)
	})
}

func (lc *LanternCore) UpdateTelemetryConsent(consent bool) error {
	slog.Debug("Updating telemetry consent", "consent", consent)
	if consent {
		slog.Info("User has opted in to telemetry")
		lc.rad.EnableTelemetry()
	} else {
		slog.Info("User has opted out of telemetry")
		lc.rad.DisableTelemetry()
	}
	return nil
}

func (lc *LanternCore) SetSmartRoutingMode(mode bool) error {
	slog.Debug("Setting Smart Routing Mode to:", "mode", mode)
	if err := vpn.SetSmartRouting(mode); err != nil {
		return fmt.Errorf("failed to set Smart Routing Mode: %w", err)
	}
	return nil
}

func (lc *LanternCore) GetSmartRoutingMode() bool {
	return vpn.SmartRoutingEnabled()
}

// Internal methods
// notifyFlutter sends an event to the Flutter frontend via the event emitter.
// On mobile we use EventChannel; on desktop this goes over the FFI event port
func (lc *LanternCore) notifyFlutter(event EventType, message string) {
	slog.Debug("Notifying Flutter")
	lc.eventEmitter.SendEvent(&utils.FlutterEvent{
		Type:    string(event),
		Message: message,
	})
}

type backgroundListenerManager struct {
	cancel    context.CancelFunc
	isRunning bool
	mu        sync.Mutex
}

var listenerManager = &backgroundListenerManager{
	// avoid nil cancel
	cancel: func() {},
}

func (lc *LanternCore) StartBackgroundListeners() {
	slog.Info("Starting background listeners...")
	listenerManager.mu.Lock()
	defer listenerManager.mu.Unlock()

	if listenerManager.isRunning {
		slog.Info("Background listeners already running")
		return
	}

	ctx, cancel := context.WithCancel(context.Background())
	listenerManager.cancel = cancel
	listenerManager.isRunning = true

	// Auto location listener
	go vpn.AutoSelectionsChangeListener(ctx)

	// DataCap SSE stream
	go func() {
		if err := lc.apiClient.DataCapStream(ctx); err != nil {
			slog.Error("datacap stopped", "error", err)
		}
	}()

	slog.Info("Background listeners started")
}

// stopAutoLocationListener stops the location listener

func (lc *LanternCore) StopBackgroundListeners() {
	slog.Info("Stopping background listeners...")
	listenerManager.mu.Lock()
	defer listenerManager.mu.Unlock()
	if !listenerManager.isRunning {
		slog.Info("Background listeners not running")
		return
	}
	listenerManager.cancel()
	listenerManager.isRunning = false
	slog.Info("Background listeners stopped")
}

// GetServerByTagJSON returns the server for a given tag as pre-marshalled JSON.
// This is safe to call from CGo callback stacks because the pointer-rich Server
// types are marshalled here rather than being returned to the caller.
func (lc *LanternCore) GetServerByTagJSON(tag string) ([]byte, bool, error) {
	return lc.serverManager.GetServerByTagJSON(tag)
}

func (lc *LanternCore) VPNStatus() (vpn.Status, error) {
	return vpn.GetStatus()
}

func (lc *LanternCore) IsVPNRunning() (bool, error) {
	st, err := vpn.GetStatus()
	if err != nil {
		return false, err
	}
	return st.TunnelOpen, nil
}

func (lc *LanternCore) IsRadianceConnected() bool {
	return lc.rad != nil
}

func (lc *LanternCore) MyDeviceId() string {
	return settings.GetString(settings.DeviceIDKey)
}

func (lc *LanternCore) UpdateLocale(locale string) error {
	slog.Debug("Updating locale", "locale", locale)
	settings.Set(settings.LocaleKey, locale)
	return nil
}

func (lc *LanternCore) ReferralAttachment(referralCode string) (bool, error) {
	return lc.apiClient.ReferralAttach(context.Background(), referralCode)
}

func (lc *LanternCore) AvailableFeatures() []byte {
	features := lc.rad.Features()
	slog.Debug("Available features", "features", features)
	jsonBytes, err := json.Marshal(features)
	if err != nil {
		slog.Error("Error marshalling features", "error", err)
		return nil
	}
	return jsonBytes
}

func (lc *LanternCore) GetAvailableServers() []byte {
	// Use ServersJSON which marshals under the lock, avoiding GC write barrier
	// panics when pointer-rich sing-box types are copied on a CGo callback stack.
	jsonBytes, err := lc.rad.ServerManager().ServersJSON()
	if err != nil {
		slog.Error("Error marshalling servers", "error", err)
		return nil
	}
	return jsonBytes
}

// LoadInstalledApps fetches the app list or rescans if needed using common macOS locations
// currently only works on/enabled for macOS
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

// SetSplitTunnelingEnabled turns split tunneling on or off for this device
func (lc *LanternCore) SetSplitTunnelingEnabled(enabled bool) {
	if enabled {
		lc.splitTunnel.Enable()
	} else {
		lc.splitTunnel.Disable()
	}
}

// IsSplitTunnelingEnabled returns whether split tunneling is currently enabled
func (lc *LanternCore) IsSplitTunnelingEnabled() bool {
	return lc.splitTunnel.IsEnabled()
}

// AddSplitTunnelItem adds a single split tunnel rule
func (lc *LanternCore) AddSplitTunnelItem(filterType, item string) error {
	return lc.splitTunnel.AddItem(filterType, item)
}

// AddSplitTunnelItems adds multiple split tunnel rules from a comma-separated string
func (lc *LanternCore) AddSplitTunnelItems(items string) error {
	split := splitCSVClean(items)

	var vpnFilter vpn.Filter
	if common.IsMacOS() {
		vpnFilter = vpn.Filter{
			ProcessPathRegex: split,
		}
	} else if common.IsWindows() {
		vpnFilter = vpn.Filter{
			ProcessPath: split,
		}
	} else {
		vpnFilter = vpn.Filter{
			PackageName: split,
		}
	}

	return lc.splitTunnel.AddItems(vpnFilter)
}

func (lc *LanternCore) RemoveSplitTunnelItems(items string) error {
	split := splitCSVClean(items)

	var vpnFilter vpn.Filter
	if common.IsMacOS() {
		vpnFilter = vpn.Filter{
			ProcessPathRegex: split,
		}
	} else if common.IsWindows() {
		vpnFilter = vpn.Filter{
			ProcessPath: split,
		}
	} else {
		vpnFilter = vpn.Filter{
			PackageName: split,
		}
	}
	return lc.splitTunnel.RemoveItems(vpnFilter)
}

// RemoveSplitTunnelItem removes a single split tunnel rule
func (lc *LanternCore) RemoveSplitTunnelItem(filterType, item string) error {
	return lc.splitTunnel.RemoveItem(filterType, item)
}

// resolveLogDir returns a directory that contains the logs
func resolveLogDir(logFilePath string) string {
	p := strings.TrimSpace(logFilePath)
	if p == "" {
		return settings.GetString(settings.LogPathKey)
	}
	if st, err := os.Stat(p); err == nil && st.IsDir() {
		return p
	}
	return filepath.Dir(p)
}

// ReportIssue is used to send an issue report via Radiance.
// We include a few helpful config files plus the main Lantern + Flutter logs when available
func (lc *LanternCore) ReportIssue(
	email, issueType, description, device, model, logFilePath string,
) error {
	report := radiance.IssueReport{
		Type:        issueType,
		Description: description,
		Device:      device,
		Model:       model,
	}

	// Attach config files from the Lantern data directory
	dataDir := settings.GetString(settings.DataPathKey)
	configFiles := []string{
		"config.json",
		"servers.json",
		"split-tunnel.json",
	}

	for _, name := range configFiles {
		path := filepath.Join(dataDir, name)
		b, err := os.ReadFile(path)
		if err != nil {
			if !os.IsNotExist(err) {
				slog.Error("Failed to read file for issue report",
					"file", name,
					"path", path,
					"error", err,
				)
			}
			continue
		}
		if len(b) == 0 {
			continue
		}

		report.Attachments = append(report.Attachments, &issue.Attachment{
			Name: name,
			Data: b,
		})
	}

	// On IOS flutter.log file should be attached separately
	// since flutter.log is in a different location due to tunnel running in a different process
	// On other platforms flutter.log is already included in the main Lantern log file
	if logFilePath != "" {
		report.Attachments = append(
			report.Attachments,
			utils.CreateLogAttachment(logFilePath)...,
		)
	}

	// Send issue report via Radiance
	if err := lc.rad.ReportIssue(email, report); err != nil {
		return fmt.Errorf("error reporting issue: %w", err)
	}

	slog.Debug("Reported issue", "type", issueType, "device", device, "model", model)
	return nil
}

// DataCapInfo returns information about this user's data cap. Only valid for free accounts
func (lc *LanternCore) DataCapInfo() (string, error) {
	return lc.apiClient.DataCapInfo(context.Background())
}

// DataCapStream starts a stream to receive data cap updates
func (lc *LanternCore) DataCapStream(ctx context.Context) error {
	return lc.apiClient.DataCapStream(ctx)
}

// User Methods
// UserData returns user data that has already been fetched.
// If user data has not been fetched yet (e.g., for a first-time user), this method will return an error.
// This is expected behavior and not necessarily a problem.
func (lc *LanternCore) UserData() ([]byte, error) {
	return lc.apiClient.UserData()
}

// FetchUserData will get the user data from the server
func (lc *LanternCore) FetchUserData() ([]byte, error) {
	return lc.apiClient.FetchUserData(context.Background())
}

// OAuth Methods
func (lc *LanternCore) OAuthLoginUrl(provider string) (string, error) {
	return lc.apiClient.OAuthLoginUrl(context.Background(), provider)
}

func (lc *LanternCore) OAuthLoginCallback(oAuthToken string) ([]byte, error) {
	return lc.apiClient.OAuthLoginCallback(context.Background(), oAuthToken)
}

func (lc *LanternCore) StripeSubscriptionPaymentRedirect(subscriptionType, planID, email string) (string, error) {
	redirectBody := api.PaymentRedirectData{
		Provider:    "stripe",
		Plan:        planID,
		DeviceName:  settings.GetString(settings.DeviceIDKey),
		Email:       email,
		BillingType: api.SubscriptionType(subscriptionType),
	}
	return lc.SubscriptionPaymentRedirectURL(redirectBody)
}

func (lc *LanternCore) StripeSubscription(email, planID string) (string, error) {
	slog.Debug("Creating stripe subscription")
	return lc.apiClient.NewStripeSubscription(context.Background(), email, planID)
}

func (lc *LanternCore) Plans(channel string) (string, error) {
	slog.Debug("Getting plans")
	return lc.apiClient.SubscriptionPlans(context.Background(), channel)
}
func (lc *LanternCore) StripeBillingPortalUrl() (string, error) {
	slog.Debug("Getting stripe billing portal")
	return lc.apiClient.StripeBillingPortalUrl(context.Background())
}

func (lc *LanternCore) AcknowledgeGooglePurchase(purchaseToken, planId string) (string, error) {
	slog.Debug("Purchase token: ", "token", purchaseToken, "planId", planId)
	params := map[string]string{
		"purchaseToken": purchaseToken,
		"planId":        planId,
	}
	status, err := lc.apiClient.VerifySubscription(context.Background(), api.GoogleService, params)
	if err != nil {
		return "", fmt.Errorf("error acknowledging google purchase: %w", err)
	}
	slog.Debug("acknowledge google purchase:", "status", status)
	return status, nil
}

func (lc *LanternCore) AcknowledgeApplePurchase(receipt, planII string) (string, error) {
	params := map[string]string{
		"receipt": receipt,
		"planId":  planII,
	}
	data, err := lc.apiClient.VerifySubscription(context.Background(), api.AppleService, params)
	if err != nil {
		return "", fmt.Errorf("error acknowledging apple purchase: %w", err)
	}
	slog.Debug("acknowledge apple purchase: ", "data", data)
	return data, nil
}

func (lc *LanternCore) SubscriptionPaymentRedirectURL(redirectBody api.PaymentRedirectData) (string, error) {
	slog.Debug("Getting payment redirect URL")
	return lc.apiClient.SubscriptionPaymentRedirectURL(context.Background(), redirectBody)
}

func (lc *LanternCore) PaymentRedirect(provider, planId, email string) (string, error) {
	slog.Debug("Payment redirect")
	deviceName := settings.GetString(settings.DeviceIDKey)
	body := api.PaymentRedirectData{
		Provider:   provider,
		Plan:       planId,
		DeviceName: deviceName,
		Email:      email,
	}
	paymentRedirect, err := lc.apiClient.PaymentRedirect(context.Background(), body)
	if err != nil {
		return "", fmt.Errorf("error getting payment redirect: %w", err)
	}
	slog.Debug("Payment redirect response: ", "response", paymentRedirect)
	return paymentRedirect, nil
}

/// User management apis

func (lc *LanternCore) Login(email, password string) ([]byte, error) {
	slog.Debug("Logging in user")
	return lc.apiClient.Login(context.Background(), email, password)
}

func (lc *LanternCore) SignUp(email, password string) error {
	slog.Debug("Signing up user")
	salt, body, err := lc.apiClient.SignUp(context.Background(), email, password)
	if err != nil {
		return fmt.Errorf("error signing up: %w", err)
	}
	slog.Debug("SignUp response: ", "salt", salt, "body", body)
	return nil
}

func (lc *LanternCore) Logout(email string) ([]byte, error) {
	slog.Debug("Logging out")
	return lc.apiClient.Logout(context.Background(), email)
}

// Email Recovery Methods
// This will start the email recovery process by sending a recovery code to the user's email
func (lc *LanternCore) StartRecoveryByEmail(email string) error {
	slog.Debug("Starting change email")
	return lc.apiClient.StartRecoveryByEmail(context.Background(), email)
}

// This will validate the recovery code sent to the user's email
func (lc *LanternCore) ValidateChangeEmailCode(email, code string) error {
	slog.Debug("Validating change email code")
	return lc.apiClient.ValidateEmailRecoveryCode(context.Background(), email, code)
}

// This will complete the email recovery by setting the new password
func (lc *LanternCore) CompleteRecoveryByEmail(email, password, code string) error {
	slog.Debug("Completing email recovery")
	return lc.apiClient.CompleteRecoveryByEmail(context.Background(), email, password, code)
}

func (lc *LanternCore) DeleteAccount(email, password string, isOAuthUser bool) ([]byte, error) {
	slog.Debug("Deleting account")
	return lc.apiClient.DeleteAccount(context.Background(), email, password, isOAuthUser)
}

func (lc *LanternCore) RemoveDevice(deviceID string) (*api.LinkResponse, error) {
	slog.Debug("Removing device: ", "deviceID", deviceID)
	return lc.apiClient.RemoveDevice(context.Background(), deviceID)
}

// Change email
func (lc *LanternCore) StartChangeEmail(newEmail, password string) error {
	slog.Debug("Starting change email")
	return lc.apiClient.StartChangeEmail(context.Background(), newEmail, password)
}

func (lc *LanternCore) CompleteChangeEmail(email, password, code string) error {
	slog.Debug("Completing change email")
	return lc.apiClient.CompleteChangeEmail(context.Background(), email, password, code)
}

func (lc *LanternCore) ActivationCode(email, resellerCode string) error {
	slog.Debug("Getting activation code")
	purchase, err := lc.apiClient.ActivationCode(context.Background(), email, resellerCode)
	if err != nil {
		return fmt.Errorf("error getting activation code: %w", err)
	}
	slog.Debug("ActivationCode response: ", "response", purchase)
	if purchase.Status != "ok" {
		return fmt.Errorf("activation code failed: %s", purchase.Status)
	}
	return nil
}

func (lc *LanternCore) DigitalOceanPrivateServer(events utils.PrivateServerEventListener) error {
	slog.Debug("Starting DigitalOcean private server flow")
	return privateserver.StartDigitalOceanPrivateServerFlow(events, lc.serverManager)
}

func (lc *LanternCore) GoogleCloudPrivateServer(events utils.PrivateServerEventListener) error {
	return privateserver.StartGoogleCloudPrivateServerFlow(events, lc.serverManager)
}

func (lc *LanternCore) ValidateSession() error {
	slog.Debug("Validating private server session")
	return privateserver.ValidateSession(context.Background())
}

func (lc *LanternCore) SelectAccount(account string) error {
	slog.Debug("Selecting account: ", "account", account)
	return privateserver.SelectAccount(account)
}

func (lc *LanternCore) SelectProject(project string) error {
	slog.Debug("Selecting project: ", "project", project)
	return privateserver.SelectProject(project)
}

func (lc *LanternCore) StartDeployment(location, serverName string) error {
	return privateserver.StartDeployment(location, serverName)
}

func (lc *LanternCore) CancelDeployment() error {
	return privateserver.CancelDeployment()
}

func (lc *LanternCore) AddServerManagerInstance(ip, port, accessToken, tag string, events utils.PrivateServerEventListener) error {
	return privateserver.AddServerManually(ip, port, accessToken, tag, lc.serverManager, events)
}
func (lc *LanternCore) InviteToServerManagerInstance(ip, port, accessToken, inviteName string) (string, error) {
	portInt, err := parsePort(port)
	if err != nil {
		return "", err
	}
	accessToken, err = lc.serverManager.InviteToPrivateServer(ip, portInt, accessToken, inviteName)
	if err != nil {
		return "", fmt.Errorf("error inviting to server manager instance: %w", err)
	}
	slog.Debug("Invite to server manager instance:", "ip", ip, "port", portInt, "name", inviteName)
	return accessToken, nil
}

func (lc *LanternCore) RevokeServerManagerInvite(ip, port, accessToken, inviteName string) error {
	portInt, err := parsePort(port)
	if err != nil {
		return err
	}
	slog.Debug("Revoking invite:", "name", inviteName, "ip", ip, "port", port)
	return lc.serverManager.RevokePrivateServerInvite(ip, portInt, accessToken, inviteName)
}

func (lc *LanternCore) DeleteServer(tag string) error {
	slog.Debug("Deleting server with tag: ", "tag", tag)
	return lc.serverManager.RemoveServer(tag)
}

func (lc *LanternCore) UpdatePrivateServerName(oldTag, newTag string) error {
	if oldTag == "" || newTag == "" {
		return fmt.Errorf("old and new server names must be non-empty")
	}
	if oldTag == newTag {
		return nil
	}

	// Ensure the source exists in user servers.
	userServers := lc.serverManager.Servers()[servers.SGUser]
	sourceExists := false
	for _, ep := range userServers.Endpoints {
		if ep.Tag == oldTag {
			sourceExists = true
			break
		}
	}
	if !sourceExists {
		for _, out := range userServers.Outbounds {
			if out.Tag == oldTag {
				sourceExists = true
				break
			}
		}
	}
	if !sourceExists {
		return fmt.Errorf("server with tag %q not found", oldTag)
	}

	// Prevent collisions against any existing server tag.
	if _, exists := lc.serverManager.GetServerByTag(newTag); exists {
		return fmt.Errorf("server with tag %q already exists", newTag)
	}

	for i, ep := range userServers.Endpoints {
		if ep.Tag == oldTag {
			userServers.Endpoints[i].Tag = newTag
		}
	}
	for i, out := range userServers.Outbounds {
		if out.Tag == oldTag {
			userServers.Outbounds[i].Tag = newTag
		}
	}
	if loc, ok := userServers.Locations[oldTag]; ok {
		delete(userServers.Locations, oldTag)
		userServers.Locations[newTag] = loc
	}
	if err := lc.serverManager.SetServers(servers.SGUser, userServers); err != nil {
		return fmt.Errorf("failed to rename private server %q to %q: %w", oldTag, newTag, err)
	}
	return nil
}

func parsePort(port string) (int, error) {
	portInt, err := strconv.Atoi(port)
	if err != nil {
		return 0, fmt.Errorf("invalid port %q: %w", port, err)
	}
	if portInt <= 0 || portInt > 65535 {
		return 0, fmt.Errorf("invalid port %d: must be between 1 and 65535", portInt)
	}
	return portInt, nil
}

func (lc *LanternCore) SetBlockAdsEnabled(enabled bool) error {
	return vpn.SetAdBlock(enabled)
}

func (lc *LanternCore) IsBlockAdsEnabled() bool {
	return vpn.AdBlockEnabled()
}

func (lc *LanternCore) SetSmartRoutingEnabled(enabled bool) error {
	return vpn.SetSmartRouting(enabled)
}

func (lc *LanternCore) IsSmartRoutingEnabled() bool {
	return vpn.SmartRoutingEnabled()
}

func (lc *LanternCore) AddServerBasedOnURLs(urls string, skipCertVerification bool, serverName string) error {
	slog.Debug("Adding server based on URLs", "urls", urls, "skipCertVerification", skipCertVerification)
	return lc.serverManager.AddServerBasedOnURLs(context.Background(), urls, skipCertVerification, serverName)
}

// splitCSVClean splits a comma-separated string into a stable list
// It trims whitespace and surrounding quotes and removes duplicates
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

func (lc *LanternCore) GetSplitTunnelStateJSON() (string, error) {
	path := filepath.Join(settings.GetString(settings.DataPathKey), "split-tunnel.json")
	b, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return `{}`, nil
		}
		return "", err
	}
	if len(b) == 0 {
		return `{}`, nil
	}
	return string(b), nil
}

func (lc *LanternCore) splitTunnelHandler() (*vpn.SplitTunnel, error) {
	if lc.splitTunnel != nil {
		return lc.splitTunnel, nil
	}
	st, err := vpn.NewSplitTunnelHandler()
	if err != nil {
		return nil, err
	}
	lc.splitTunnel = st
	return st, nil
}

func (lc *LanternCore) GetSplitTunnelItems(filterType string) (string, error) {
	st, err := lc.splitTunnelHandler()
	if err != nil {
		return "", err
	}
	return st.ItemsJSON(filterType)
}

func jsonNumberToIntString(f float64) string {
	// ports are integral; safe enough here
	return string([]byte((func() string {
		n := int(f)
		return itoa(n)
	})()))
}

// tiny local itoa to avoid importing strconv in this file (optional)
func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	neg := n < 0
	if neg {
		n = -n
	}
	buf := make([]byte, 0, 12)
	for n > 0 {
		d := n % 10
		buf = append(buf, byte('0'+d))
		n /= 10
	}
	if neg {
		buf = append(buf, '-')
	}
	// reverse
	for i, j := 0, len(buf)-1; i < j; i, j = i+1, j-1 {
		buf[i], buf[j] = buf[j], buf[i]
	}
	return string(buf)
}

func (lc *LanternCore) GetAppDataDir() string {
	return settings.GetString(settings.DataPathKey)
}

func (lc *LanternCore) GetEnabledApps() (string, error) {
	st, err := lc.splitTunnelHandler()
	if err != nil {
		return "", err
	}
	return st.EnabledAppsJSON()
}

// fixStaleSettingsFilePath corrects a stale "file_path" entry in local.json that can
// occur after the iOS migration from the App Group root to the data/ subdirectory.
// The radiance settings watcher reads "file_path" from local.json to decide which
// directory to watch via fsnotify. If it still points to the App Group root, the
// Network Extension sandbox blocks lstat on
// .com.apple.mobile_container_manager.metadata.plist, causing the tunnel to fail.
// The main app always runs before the tunnel (user must tap Connect), so this fix
// is guaranteed to persist to disk before the tunnel process starts.
func fixStaleSettingsFilePath(dataDir string) {
	// "file_path" and "local.json" mirror unexported constants in the radiance settings package.
	expected := filepath.Join(dataDir, "local.json")
	current := settings.GetString("file_path")
	if current == "" || current == expected {
		return
	}
	slog.Info("Fixing stale file_path in settings", "from", current, "to", expected)
	if err := settings.Set("file_path", expected); err != nil {
		slog.Warn("Failed to fix file_path in settings", "error", err)
	}
}
