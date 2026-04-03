package lanterncore

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"strings"
	"sync"
	"sync/atomic"

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
)

type EventType = string

const (
	EventTypeServerLocation EventType = "server-location"
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
	ReferralAttachment(referralCode string) (bool, error)
	UpdateLocale(locale string) error
	StartBackgroundListeners()
	StopBackgroundListeners()
	UpdateTelemetryConsent(consent bool) error
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
	DeleteAccount(email, password string, isOAuthUser bool) ([]byte, error)
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
	SubscriptionPaymentRedirectURL(redirectBody account.PaymentRedirectData) (string, error)
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
	DisconnectVPN() error
	VPNStatus() (vpn.VPNStatus, error)
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
	go lc.listenDataCapEvents()

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
		slog.Error("auto-selected event stream ended", "error", err)
	}
}

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
		slog.Error("datacap event stream ended", "error", err)
	}
}

/////////////////
//     VPN     //
/////////////////

func (lc *LanternCore) ConnectVPN(tag string) error {
	return lc.client.ConnectVPN(lc.ctx, tag)
}

func (lc *LanternCore) DisconnectVPN() error {
	return lc.client.DisconnectVPN(lc.ctx)
}

func (lc *LanternCore) VPNStatus() (vpn.VPNStatus, error) {
	return lc.client.VPNStatus(lc.ctx)
}

func (lc *LanternCore) IsVPNRunning() (bool, error) {
	status, err := lc.client.VPNStatus(lc.ctx)
	if err != nil {
		return false, err
	}
	return status == vpn.Connected, nil
}

/////////////////
//  Settings   //
/////////////////

func (lc *LanternCore) UpdateTelemetryConsent(consent bool) error {
	return lc.client.EnableTelemetry(lc.ctx, consent)
}

func (lc *LanternCore) SetBlockAdsEnabled(enabled bool) error {
	return lc.client.EnableAdBlocking(lc.ctx, enabled)
}

func (lc *LanternCore) IsBlockAdsEnabled() bool {
	s, err := lc.client.Settings(lc.ctx)
	if err != nil {
		return false
	}
	v, ok := s[settings.AdBlockKey]
	if !ok {
		return false
	}
	b, _ := v.(bool)
	return b
}

func (lc *LanternCore) SetSmartRoutingEnabled(enabled bool) error {
	return lc.client.EnableSmartRouting(lc.ctx, enabled)
}

func (lc *LanternCore) IsSmartRoutingEnabled() bool {
	s, err := lc.client.Settings(lc.ctx)
	if err != nil {
		return false
	}
	v, ok := s[settings.SmartRoutingKey]
	if !ok {
		return false
	}
	b, _ := v.(bool)
	return b
}

func (lc *LanternCore) IsRadianceConnected() bool {
	return lc.client != nil
}

func (lc *LanternCore) MyDeviceId() string {
	s, err := lc.client.Settings(lc.ctx)
	if err != nil {
		return ""
	}
	v, _ := s[settings.DeviceIDKey].(string)
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
	srvs, err := lc.client.Servers(lc.ctx)
	if err != nil {
		slog.Error("Error getting servers", "error", err)
		return nil
	}
	jsonBytes, err := json.Marshal(srvs)
	if err != nil {
		slog.Error("Error marshalling servers", "error", err)
		return nil
	}
	return jsonBytes
}

func (lc *LanternCore) GetServerByTagJSON(tag string) ([]byte, bool, error) {
	server, found, err := lc.client.GetServerByTag(lc.ctx, tag)
	if err != nil {
		return nil, false, err
	}
	if !found {
		return nil, false, nil
	}
	jsonBytes, err := json.Marshal(server)
	if err != nil {
		return nil, false, fmt.Errorf("error marshalling server: %w", err)
	}
	return jsonBytes, true, nil
}

/////////////////////
// Background      //
/////////////////////

var listenerManager = &backgroundListenerManager{
	cancel: func() {},
}

type backgroundListenerManager struct {
	cancel    context.CancelFunc
	isRunning bool
	mu        sync.Mutex
}

func (lc *LanternCore) StartBackgroundListeners() {
	slog.Info("Starting background listeners...")
	listenerManager.mu.Lock()
	defer listenerManager.mu.Unlock()

	if listenerManager.isRunning {
		slog.Info("Background listeners already running")
		return
	}

	_, cancel := context.WithCancel(lc.ctx)
	listenerManager.cancel = cancel
	listenerManager.isRunning = true

	// Auto-selected and data cap listeners are already running from initialization.
	// This method is kept for compatibility but the listeners start automatically.
	slog.Info("Background listeners started")
}

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

func (lc *LanternCore) SetSplitTunnelingEnabled(enabled bool) {
	if err := lc.client.EnableSplitTunneling(lc.ctx, enabled); err != nil {
		slog.Error("Error setting split tunneling", "error", err)
	}
}

func (lc *LanternCore) IsSplitTunnelingEnabled() bool {
	s, err := lc.client.Settings(lc.ctx)
	if err != nil {
		return false
	}
	v, ok := s[settings.SplitTunnelKey]
	if !ok {
		return false
	}
	b, _ := v.(bool)
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
	// Return all process-based items as enabled apps
	var enabledApps []string
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
	if logFilePath != "" {
		attachments = append(attachments, logFilePath)
	}
	return lc.client.ReportIssue(lc.ctx, it, description, email, attachments)
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

func (lc *LanternCore) DeleteAccount(email, password string, _ bool) ([]byte, error) {
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

	// Get current servers to find the one being renamed
	srvs, err := lc.client.Servers(lc.ctx)
	if err != nil {
		return fmt.Errorf("failed to get servers: %w", err)
	}

	// Check source exists in user servers
	userServers, ok := srvs[servers.SGUser]
	if !ok {
		return fmt.Errorf("no user servers found")
	}

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

	// Check new tag doesn't collide
	_, exists, _ := lc.client.GetServerByTag(lc.ctx, newTag)
	if exists {
		return fmt.Errorf("server with tag %q already exists", newTag)
	}

	// Rename by updating the options
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

	// Remove old, add new
	if err := lc.client.RemoveServers(lc.ctx, []string{oldTag}); err != nil {
		return fmt.Errorf("failed to remove old server %q: %w", oldTag, err)
	}
	if err := lc.client.AddServers(lc.ctx, servers.SGUser, userServers); err != nil {
		return fmt.Errorf("failed to add renamed server %q: %w", newTag, err)
	}
	return nil
}

func (lc *LanternCore) AddServerBasedOnURLs(urls string, skipCertVerification bool, _ string) error {
	urlList := strings.Split(urls, ",")
	for i, u := range urlList {
		urlList[i] = strings.TrimSpace(u)
	}
	return lc.client.AddServersByURL(lc.ctx, urlList, skipCertVerification)
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
