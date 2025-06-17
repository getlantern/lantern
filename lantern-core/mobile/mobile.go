package mobile

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"time"

	"github.com/getlantern/golog"
	privateserver "github.com/getlantern/lantern-outline/lantern-core/private-server"
	pcommon "github.com/getlantern/lantern-server-provisioner/common"

	"github.com/getlantern/lantern-outline/lantern-core/utils"
	"github.com/getlantern/radiance"
	"github.com/getlantern/radiance/api"
	"github.com/getlantern/radiance/api/protos"
	"github.com/getlantern/radiance/client"
	boxservice "github.com/getlantern/radiance/client/service"
	"github.com/getlantern/radiance/common"

	"google.golang.org/protobuf/proto"

	"github.com/sagernet/sing-box/experimental/libbox"
	_ "golang.org/x/mobile/bind"
)

var (
	log            = golog.LoggerFor("lantern-outline.native")
	radianceMutex  = sync.Mutex{}
	radianceServer *lanternService
	vpnClient      client.VPNClient

	setupRadiance   sync.Once
	setupRVPNClient sync.Once
)

type lanternService struct {
	*radiance.Radiance
	userConfig common.UserInfo
	apiClient  *api.APIClient
}
type Opts struct {
	DataDir  string
	Deviceid string
	Locale   string
}

func enableSplitTunneling() bool {
	return runtime.GOOS == "android"
}

func SetupRadiance(opts *Opts) error {
	var innerErr error
	setupRadiance.Do(func() {
		logDir := filepath.Join(opts.DataDir, "logs")
		if err := os.MkdirAll(opts.DataDir, 0o777); err != nil {
			log.Errorf("unable to create data directory: %v", err)
		}
		if err := os.MkdirAll(logDir, 0o777); err != nil {
			log.Errorf("unable to create log directory: %v", err)
		}
		clientOpts := radiance.Options{
			LogDir:   logDir,
			DataDir:  opts.DataDir,
			Locale:   opts.Locale,
			DeviceID: opts.Deviceid,
		}
		r, err := radiance.NewRadiance(clientOpts)
		log.Debugf("Paths: %s %s", logDir, opts.DataDir)
		if err != nil {
			innerErr = fmt.Errorf("unable to create Radiance: %v", err)
			return
		}
		radianceServer = &lanternService{
			Radiance:   r,
			userConfig: r.UserInfo(),
			apiClient:  r.APIHandler(),
		}
		log.Debug("Radiance setup successfully")
		if radianceServer.userConfig.LegacyID() == 0 {
			log.Debug("Creating user")
			CreateUser()
		}
		FetchUserData()
	})

	if innerErr != nil {
		return innerErr
	}
	return nil
}

func NewVPNClient(opts *Opts, platform libbox.PlatformInterface) error {
	var innerErr error
	setupRVPNClient.Do(func() {
		logDir := filepath.Join(opts.DataDir, "logs")
		client, err := client.NewVPNClient(opts.DataDir, logDir, platform, enableSplitTunneling())
		if err != nil {
			innerErr = fmt.Errorf("unable to create vpn client: %v", err)
			return
		}
		vpnClient = client
		log.Debugf("VPN client setup successfully")
	})
	if innerErr != nil {
		return innerErr
	}
	return nil
}

func IsRadianceConnected() bool {
	radianceMutex.Lock()
	defer radianceMutex.Unlock()
	return radianceServer != nil
}

func StartVPN() error {
	log.Debug("Starting VPN")
	radianceMutex.Lock()
	defer radianceMutex.Unlock()
	if vpnClient == nil {
		return log.Error("VPN client not setup")
	}
	err := vpnClient.StartVPN()
	if err != nil {
		log.Errorf("Error starting VPN: %v", err)
		return err
	}
	return nil
}

func StopVPN() error {
	log.Debug("Stopping VPN")
	radianceMutex.Lock()
	defer radianceMutex.Unlock()
	if vpnClient == nil {
		return log.Error("VPN client not setup")
	}
	er := vpnClient.StopVPN()
	if er != nil {
		log.Errorf("Error stopping VPN: %v", er)
	}
	return nil
}

func IsVPNConnected() bool {
	radianceMutex.Lock()
	defer radianceMutex.Unlock()
	if vpnClient == nil {
		return false
	}
	return vpnClient.ConnectionStatus()
}

func AddSplitTunnelItem(filterType, item string) error {
	radianceMutex.Lock()
	defer radianceMutex.Unlock()
	if vpnClient == nil {
		return log.Error("Radiance not setup")
	}

	if err := vpnClient.SplitTunnelHandler().AddItem(filterType, item); err != nil {
		return fmt.Errorf("error adding item: %v", err)
	}
	log.Debugf("added %s split tunneling item %s", filterType, item)
	return nil
}

func RemoveSplitTunnelItem(filterType, item string) error {
	radianceMutex.Lock()
	defer radianceMutex.Unlock()
	if vpnClient == nil {
		return log.Error("Radiance not setup")
	}

	if err := vpnClient.SplitTunnelHandler().RemoveItem(filterType, item); err != nil {
		return fmt.Errorf("error removing item: %v", err)
	}
	log.Debugf("removed %s split tunneling item %s", filterType, item)
	return nil
}

// User Methods
// Todo make sure to add retry logic
// we need to make sure that the user is created before we can use the radiance server
func CreateUser() (*api.UserDataResponse, error) {
	log.Debug("Creating user")
	user, err := radianceServer.apiClient.NewUser(context.Background())
	log.Debugf("UserCreate response: %v", user)
	if err != nil {
		return nil, log.Errorf("Error creating user: %v", err)
	}
	return user, nil
}

// this will return the user data from the user config
func UserData() ([]byte, error) {
	user, err := radianceServer.userConfig.GetData()
	if err != nil {
		return nil, log.Errorf("Error getting user data: %v", err)
	}
	fmt.Printf("UserData: %v\n", user)
	bytes, err := proto.Marshal(user)
	if err != nil {
		return nil, log.Errorf("Error marshalling user data: %v", err)
	}
	return bytes, nil
}

// GetUserData will get the user data from the server
func FetchUserData() ([]byte, error) {
	log.Debug("Getting user data")
	//this call will also save the user data in the user config
	// so we can use it later
	user, err := radianceServer.apiClient.UserData(context.Background())
	if err != nil {
		return nil, log.Errorf("Error getting user data: %v", err)
	}
	log.Debugf("UserData response: %v", user)
	login := &protos.LoginResponse{
		LegacyID:       user.UserId,
		LegacyToken:    user.Token,
		LegacyUserData: user.LoginResponse_UserData,
	}
	protoUserData, err := proto.Marshal(login)
	if err != nil {
		return nil, log.Errorf("Error marshalling user data: %v", err)
	}
	return protoUserData, nil
}

// OAuth Methods
func OAuthLoginUrl(provider string) (string, error) {
	log.Debug("Getting OAuth login URL")
	oauthLoginUrl, err := radianceServer.apiClient.OAuthLoginUrl(context.Background(), provider)
	if err != nil {
		return "", log.Errorf("Error getting OAuth login URL: %v", err)
	}
	log.Debugf("OAuthLoginUrl response: %v", oauthLoginUrl)
	return oauthLoginUrl, nil
}

func OAuthLoginCallback(oAuthToken string) ([]byte, error) {
	log.Debug("Getting OAuth login callback")
	userInfo, err := utils.DecodeJWT(oAuthToken)
	if err != nil {
		return nil, log.Errorf("Error decoding JWT: %v", err)
	}
	// Temporary  set user data to so api can read it
	login := &protos.LoginResponse{
		LegacyID:    userInfo.LegacyUserId,
		LegacyToken: userInfo.LegacyToken,
	}
	radianceServer.userConfig.SetData(login)
	///Get user data from api this will also save data in user config
	user, err := radianceServer.apiClient.UserData(context.Background())
	if err != nil {
		return nil, log.Errorf("Error getting user data: %v", err)
	}
	log.Debugf("UserData response: %v", user)
	userResponse := &protos.LoginResponse{
		Id:             userInfo.Email,
		EmailConfirmed: true,
		LegacyID:       user.UserId,
		LegacyToken:    user.Token,
		LegacyUserData: user.LoginResponse_UserData,
	}
	radianceServer.userConfig.SetData(userResponse)
	bytes, err := proto.Marshal(userResponse)
	if err != nil {
		return nil, log.Errorf("Error marshalling user data: %v", err)
	}
	return bytes, nil
}

func StripeSubscription(email, planId string) (string, error) {
	log.Debug("Creating stripe subscription")
	stripeSubscription, err := radianceServer.apiClient.NewStripeSubscription(context.Background(), email, planId)
	if err != nil {
		return "", log.Errorf("Error creating stripe subscription: %v", err)
	}
	log.Debugf("StripeSubscription response: %v", stripeSubscription)
	jsonData, err := json.Marshal(stripeSubscription)
	if err != nil {
		return "", log.Errorf("Error marshalling stripe subscription: %v", err)
	}
	// Convert bytes to string and print
	jsonString := string(jsonData)
	log.Debugf("StripeSubscription response: %v", jsonString)
	return jsonString, nil
}

func Plans(channel string) (string, error) {

	log.Debug("Getting plans")
	plans, err := radianceServer.apiClient.SubscriptionPlans(context.Background(), channel)
	if err != nil {
		return "", log.Errorf("Error getting plans: %v", err)
	}
	jsonData, err := json.Marshal(plans)
	if err != nil {
		return "", log.Errorf("Error marshalling plans: %v", err)
	}
	log.Debugf("Plans response: %v", string(jsonData))
	// Convert bytes to string and print
	return string(jsonData), nil
}
func StripeBillingPortalUrl() (string, error) {
	log.Debug("Getting stripe billing portal")
	billingPortal, err := radianceServer.apiClient.StripeBillingPortalUrl()
	if err != nil {
		return "", log.Errorf("Error getting stripe billing portal: %v", err)
	}
	log.Debugf("StripeBillingPortal response: %v", billingPortal)
	return billingPortal, nil
}

func AcknowledgeGooglePurchase(purchaseToken, planId string) error {
	log.Debugf("Purchase token: %s planId %s", purchaseToken, planId)
	params := map[string]string{
		"purchaseToken": purchaseToken,
		"planId":        planId,
	}
	status, _, err := radianceServer.apiClient.VerifySubscription(context.Background(), api.GoogleService, params)
	if err != nil {
		return log.Errorf("Error acknowledging: %v", err)
	}
	log.Debugf("acknowledge google purchase: %v", status)
	return nil
}

func AcknowledgeApplePurchase(receipt, planId string) error {
	log.Debugf("Apple receipt: %s planId %s", receipt, planId)
	params := map[string]string{
		"receipt": receipt,
		"planId":  planId,
	}
	status, _, err := radianceServer.apiClient.VerifySubscription(context.Background(), api.AppleService, params)
	if err != nil {
		return log.Errorf("Error acknowledging: %v", err)
	}
	log.Debugf("acknowledge apple purchase: %v", status)
	return nil
}

func PaymentRedirect(provider, planId, email string) (string, error) {
	log.Debug("Payment redirect")
	deviceName := radianceServer.userConfig.DeviceID()
	body := api.PaymentRedirectData{
		Provider:   provider,
		Plan:       planId,
		DeviceName: deviceName,
		Email:      email,
	}
	paymentRedirect, err := radianceServer.apiClient.PaymentRedirect(context.Background(), body)
	if err != nil {
		return "", log.Errorf("Error getting payment redirect: %v", err)
	}
	log.Debugf("Payment redirect response: %v", paymentRedirect)
	return paymentRedirect, nil
}

/// User management apis

func Login(email, password string) ([]byte, error) {
	log.Debug("Logging in user")
	deviceId := radianceServer.userConfig.DeviceID()
	loginResponse, err := radianceServer.apiClient.Login(context.Background(), email, password, deviceId)
	if err != nil {
		return nil, log.Errorf("%v", err)
	}
	log.Debugf("Login response: %v", loginResponse)
	protoUserData, err := proto.Marshal(loginResponse)
	if err != nil {
		return nil, log.Errorf("Error marshalling user data: %v", err)
	}
	return protoUserData, nil
}

func SignUp(email, password string) error {
	log.Debug("Signing up user")
	err := radianceServer.apiClient.SignUp(context.Background(), email, password)
	if err != nil {
		return log.Errorf("Error signing up: %v", err)
	}
	return nil
}

func Logout(email string) ([]byte, error) {
	log.Debug("Logging out")
	err := radianceServer.apiClient.Logout(context.Background(), email)
	if err != nil {
		return nil, log.Errorf("Error logging out: %v", err)
	}
	//this call will save data
	user, err := CreateUser()
	if err != nil {
		return nil, log.Errorf("Error creating user: %v", err)
	}
	login := &protos.LoginResponse{
		LegacyID:       user.UserId,
		LegacyToken:    user.Token,
		LegacyUserData: user.LoginResponse_UserData,
	}
	protoUserData, err := proto.Marshal(login)
	if err != nil {
		return nil, log.Errorf("Error marshalling user data: %v", err)
	}
	return protoUserData, nil
}

// Email Recovery Methods
// This will start the email recovery process by sending a recovery code to the user's email
func StartRecoveryByEmail(email string) error {
	log.Debug("Starting change email")
	err := radianceServer.apiClient.StartRecoveryByEmail(context.Background(), email)
	if err != nil {
		return log.Errorf("Error starting change email: %v", err)
	}
	return nil
}

// This will validate the recovery code sent to the user's email
func ValidateChangeEmailCode(email, code string) error {
	log.Debug("Validating change email code")
	err := radianceServer.apiClient.ValidateEmailRecoveryCode(context.Background(), email, code)
	if err != nil {
		return log.Errorf("Error validating change email code: %v", err)
	}
	log.Debugf("ValidateChangeEmailCode Sucessful for email: %s", email)
	return nil
}

// This will complete the email recovery by setting the new password
func CompleteChangeEmail(email, password, code string) error {
	log.Debug("Completing change email")
	err := radianceServer.apiClient.CompleteRecoveryByEmail(context.Background(), email, password, code)
	if err != nil {
		return log.Errorf("Error completing change email: %v", err)
	}
	return nil
}

func DeleteAccount(email, password string) ([]byte, error) {
	log.Debug("Deleting account")
	err := radianceServer.apiClient.DeleteAccount(context.Background(), email, password)
	if err != nil {
		return nil, log.Errorf("Error deleting account: %v", err)
	}
	user, err := CreateUser()
	if err != nil {
		return nil, log.Errorf("Error creating user: %v", err)
	}
	login := &protos.LoginResponse{
		LegacyID:       user.UserId,
		LegacyToken:    user.Token,
		LegacyUserData: user.LoginResponse_UserData,
	}
	protoUserData, err := proto.Marshal(login)
	if err != nil {
		return nil, log.Errorf("Error marshalling user data: %v", err)
	}
	radianceServer.userConfig.SetData(login)
	return protoUserData, nil
}

func ActivationCode(email, resellerCode string) error {
	log.Debug("Getting activation code")
	purchase, err := radianceServer.apiClient.ActivationCode(context.Background(), email, resellerCode)
	if err != nil {
		return log.Errorf("Error getting activation code: %v", err)
	}
	log.Debugf("ActivationCode response: %v", purchase)
	if purchase.Status != "ok" {
		return fmt.Errorf("activation code failed: %s", purchase.Status)
	}
	return nil
}

type PrivateServerEventListener interface {
	OpenBrowser(url string) error
	OnPrivateServerEvent(event string)
	OnError(err string)
}

type ProvisionSession struct {
	Provisioner         pcommon.Provisioner
	EventSink           PrivateServerEventListener
	CurrentCompartments []pcommon.Compartment
	userCompartment     *pcommon.Compartment
	userProject         *pcommon.CompartmentEntry
	userProjectString   string
	serverName          string
}

type ProvisionerResponse struct {
	ExternalIP  string `json:"external_ip"`
	Port        int    `json:"port"`
	AccessToken string `json:"access_token"`
	Tag         string `json:"tag"`
}

var sessions = sync.Map{}

// sync mutex
var provisionerMutex sync.Mutex

func DigitalOceanPrivateServer(events PrivateServerEventListener) error {
	provisioner := privateserver.AddDigitalOceanServerRoutes(context.Background(), func(url string) error {
		return events.OpenBrowser(url)
	})
	session := provisioner.Session()
	if session == nil {
		return log.Error("Failed to strat DigitalOcean provisioner")
	}
	ps := &ProvisionSession{
		Provisioner: provisioner,
		EventSink:   events,
	}
	storeSession(ps)
	go listenToServerEvents(*ps)
	return nil
}
func storeSession(ps *ProvisionSession) {
	provisionerMutex.Lock()
	defer provisionerMutex.Unlock()
	log.Debug("Storing provision session in sessions map")
	sessions.Store("provisioner", ps)
}

func getSession() (*ProvisionSession, error) {
	provisionerMutex.Lock()
	defer provisionerMutex.Unlock()
	val, ok := sessions.Load("provisioner")
	log.Debug("Getting provision session from sessions map")
	if !ok {
		log.Error("No active session found")
		return nil, errors.New("no active session")
	}
	return val.(*ProvisionSession), nil
}

func listenToServerEvents(ps ProvisionSession) {
	provisioner := ps.Provisioner
	session := ps.Provisioner.Session()
	events := ps.EventSink
	log.Debug("Listening to private server events")
	for {
		select {
		case e := <-session.Events:
			switch e.Type {
			// OAuth events
			case pcommon.EventTypeOAuthStarted:
				log.Debug("OAuth started, waiting for user to complete")
				events.OnPrivateServerEvent(convertStatusToJSON("EventTypeOAuthStarted", "OAuth started, waiting for user to complete"))
			case pcommon.EventTypeOAuthCancelled:
				log.Debug("OAuth cancelled by user")
				events.OnError(convertErrorToJSON("EventTypeOAuthCancelled", fmt.Errorf("OAuth cancelled by user")))
				return
			case pcommon.EventTypeOAuthError:
				log.Errorf("OAuth failed", e.Error)
				events.OnError(convertErrorToJSON("EventTypeOAuthError", e.Error))
				return

				// Validation events
			case pcommon.EventTypeOAuthCompleted:
				log.Debugf("OAuth completed", e.Message)
				// we have the token, now we can proceed
				// this will start the validation process, preparing a list of healthy projects
				// and billing accounts that can be used
				events.OnPrivateServerEvent(convertStatusToJSON("EventTypeOAuthCompleted", "OAuth completed, starting validation"))
				provisioner.Validate(context.Background(), e.Message)
				continue
			case pcommon.EventTypeValidationStarted:
				log.Debug("Validation started")
				events.OnPrivateServerEvent(convertStatusToJSON("EventTypeValidationStarted", "Validation started, please wait..."))
			case pcommon.EventTypeValidationError:
				log.Errorf("Validation failed", e.Error)
				events.OnError(convertErrorToJSON("EventTypeValidationError", e.Error))
				return
			case pcommon.EventTypeValidationCompleted:
				// at this point we have a list of projects and billing accounts
				// present them to the user
				// log.Debug("Validation completed, ready to create resources")
				compartments := provisioner.Compartments()
				if len(compartments) == 0 {
					log.Error("No valid projects found, please check your billing account and permissions")
					events.OnError("No valid projects found, please check your billing account and permissions")
					return
				}
				ps.CurrentCompartments = compartments
				// update map
				sessions.Store("provisioner", &ps)
				log.Debug("Validation completed, ready to create resources")
				//Accounts
				//send account to the client
				accountNames := pcommon.CompartmentNames(compartments)
				log.Debugf("Available accounts: %v", strings.Join(accountNames, ", "))
				events.OnPrivateServerEvent(convertStatusToJSON("EventTypeAccounts", strings.Join(accountNames, ", ")))

			case pcommon.EventTypeProvisioningStarted:
				log.Debug("Provisioning started")
				events.OnPrivateServerEvent(convertStatusToJSON("EventTypeProvisioningStarted", "Provisioning started, please wait..."))
			case pcommon.EventTypeProvisioningCompleted:
				log.Debugf("Provisioning completed successfully %s", e.Message)
				//get session
				provisioner, perr := getSession()
				if perr != nil {
					events.OnError(convertErrorToJSON("EventTypeProvisioningError", perr))
				}
				// we have the response, now we can add the server manager instance
				resp := ProvisionerResponse{}
				err := json.Unmarshal([]byte(e.Message), &provisioner)
				if err != nil {
					log.Errorf("Error unmarshalling provisioner response: %v", err)
					events.OnError(convertErrorToJSON("EventTypeProvisioningError", err))
					return
				}
				resp.Tag = provisioner.serverName
				mangerErr := AddServerManagerInstance(resp)
				if mangerErr != nil {
					log.Errorf("Error adding server manager instance: %v", mangerErr)
					events.OnError(convertErrorToJSON("EventTypeProvisioningError", mangerErr))
					return
				}
				server, err := json.Marshal(resp)
				if err != nil {
					log.Errorf("Error marshalling server response: %v", err)
					events.OnError(convertErrorToJSON("EventTypeProvisioningError", mangerErr))
				}

				events.OnPrivateServerEvent(convertStatusToJSON("EventTypeProvisioningCompleted", string(server)))
				return
			case pcommon.EventTypeProvisioningError:
				log.Errorf("Provisioning failed", e.Error)
				events.OnError(convertErrorToJSON("EventTypeProvisioningError", e.Error))
				return
			}

		default:
			time.Sleep(1 * time.Second)
		}
	}
}

func SelectAccount(name string) error {
	log.Debugf("Selecting account: %s", name)
	ps, err := getSession()
	if err != nil {
		return err
	}
	//Store the user selected compartment
	userCompartment := pcommon.CompartmentByName(ps.CurrentCompartments, name)
	ps.userCompartment = userCompartment
	storeSession(ps)
	// Send the user selected compartment to the event sink
	projectList := pcommon.CompartmentEntryIDs(userCompartment.Entries)
	ps.EventSink.OnPrivateServerEvent(convertStatusToJSON("EventTypeProjects", strings.Join(projectList, ", ")))
	return nil
}

func SelectProject(selectedProject string) error {
	ps, err := getSession()
	if err != nil {
		return err
	}
	log.Debugf("Selecting project:%s", selectedProject)
	//Store the user selected project
	project := pcommon.CompartmentEntryByID(ps.userCompartment.Entries, selectedProject)
	log.Debugf("Selected project: %v", project)
	ps.userProject = project
	ps.userProjectString = selectedProject
	storeSession(ps)
	//Send location list to the event sink
	locationList := pcommon.CompartmentEntryLocations(project)
	ps.EventSink.OnPrivateServerEvent(convertStatusToJSON("EventTypeLocations", strings.Join(locationList, ", ")))
	return nil
}

func StartDepolyment(selectedLocation string, serverName_ string) error {
	//Recovery
	defer func() {
		if r := recover(); r != nil {
			log.Errorf("Recovered from panic: %v", r)
		}
	}()

	ps, err := getSession()
	if err != nil {
		return err
	}
	if ps.userProject == nil {
		log.Debugf("Project not selected, please select a project first")
	}
	log.Debugf("Starting deployment in location: %s name %s", selectedLocation, serverName_)
	cloc := pcommon.CompartmentLocationByIdentifier(ps.userProject.Locations, selectedLocation)
	ps.serverName = serverName_
	storeSession(ps)
	ps.Provisioner.Provision(context.Background(), ps.userProjectString, cloc.GetID())
	return nil
}

func AddServerManagerInstance(resp ProvisionerResponse) error {
	return vpnClient.AddServerManagerInstance(resp.Tag, resp.ExternalIP, resp.Port, resp.AccessToken, func(ip string, details []boxservice.CertDetail) *boxservice.CertDetail {
		log.Debugf("Adding server manager instance: %s", ip)
		if len(details) == 0 {
			return nil
		}
		log.Debugf("Server manager instance details: %v", details[0])
		return &details[0]
	})
}

func CancelDepolyment() error {
	ps, err := getSession()
	if err != nil {
		return err
	}
	log.Debug("Cancelling provisioning")
	ps.Provisioner.Session().Cancel()
	ps.EventSink.OnPrivateServerEvent(convertStatusToJSON("EventTypeProvisioningCancelled", "Provisioning cancelled by user"))
	return nil
}

func convertStatusToJSON(status, data string) string {
	mapStatus := map[string]string{
		"status": status,
		"data":   data,
	}
	jsonData, _ := json.Marshal(mapStatus)
	return string(jsonData)
}

func convertErrorToJSON(status string, err error) string {
	if err == nil {
		return ""
	}
	mapError := map[string]string{
		"status": status,
		"error":  err.Error(),
	}
	jsonData, _ := json.Marshal(mapError)
	return string(jsonData)
}
