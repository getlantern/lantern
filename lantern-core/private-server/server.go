package privateserver

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/getlantern/golog"
	"github.com/getlantern/lantern/lantern-core/utils"
	pcommon "github.com/getlantern/lantern-server-provisioner/common"
	"github.com/getlantern/lantern-server-provisioner/digitalocean"
	gcp "github.com/getlantern/lantern-server-provisioner/gcp"
	"github.com/getlantern/radiance/servers"
)

var (
	log                 = golog.LoggerFor("privateserver")
	provisionerMutex    sync.Mutex
	sessions            = sync.Map{}
	certFingerprintChan = make(chan string, 1)
)

type provisionSession struct {
	provisioner         pcommon.Provisioner
	eventSink           utils.PrivateServerEventListener
	CurrentCompartments []pcommon.Compartment
	userCompartment     *pcommon.Compartment
	userProject         *pcommon.CompartmentEntry
	authToken           string
	userProjectString   string
	serverName          string
	serverLocation      string
	manager             *servers.Manager
}

type provisionerResponse struct {
	ExternalIP  string `json:"external_ip"`
	Port        int    `json:"port"`
	AccessToken string `json:"access_token"`
	Tag         string `json:"tag"`
	Location    string `json:"location,omitempty"`
	Protocol    string `json:"protocol,omitempty"`
}

type certSummary struct {
	Fingerprint string `json:"fingerprint"`
	Issuer      string `json:"issuer"`
	Subject     string `json:"subject"`
}

// storeSession stores the provision session in a global map.
func storeSession(ps *provisionSession) {
	provisionerMutex.Lock()
	defer provisionerMutex.Unlock()
	log.Debug("Storing provision session in sessions map")
	sessions.Store("provisioner", ps)
}

// getSession retrieves the provision session from the global map.
func getSession() (*provisionSession, error) {
	provisionerMutex.Lock()
	defer provisionerMutex.Unlock()
	val, ok := sessions.Load("provisioner")
	log.Debug("Getting provision session from sessions map")
	if !ok {
		log.Error("No active session found")
		return nil, errors.New("no active session")
	}
	return val.(*provisionSession), nil
}

// StartDigitalOceanPrivateServerFlow initializes the DigitalOcean provisioner and starts listening for events.
// It takes a PrivateServerEventListener to handle events and browser opening.
// It returns an error if the provisioner fails to start or if there are issues during the session.
func StartDigitalOceanPrivateServerFlow(events utils.PrivateServerEventListener, vpnClient *servers.Manager) error {
	ctx := context.Background()
	provisioner := digitalocean.GetProvisioner(ctx, func(url string) error {
		return events.OpenBrowser(url)
	})
	session := provisioner.Session()
	if session == nil {
		return log.Error("Failed to strat DigitalOcean provisioner")
	}
	ps := &provisionSession{
		provisioner: provisioner,
		eventSink:   events,
		manager:     vpnClient,
	}
	storeSession(ps)
	go listenToServerEvents(*ps)
	return nil
}

// StartGoogleCloudPrivateServerFlow initializes the GCP provisioner and starts listening for events
func StartGoogleCloudPrivateServerFlow(events utils.PrivateServerEventListener, vpnClient *servers.Manager) error {
	ctx := context.Background()
	provisioner := gcp.GetProvisioner(ctx, func(url string) error {
		return events.OpenBrowser(url)
	})
	session := provisioner.Session()
	if session == nil {
		return log.Error("Failed to start Google Cloud provisioner")
	}
	ps := &provisionSession{
		provisioner: provisioner,
		eventSink:   events,
		manager:     vpnClient,
	}
	storeSession(ps)
	go listenToServerEvents(*ps)
	return nil
}

// listenToServerEvents listens for events from the provisioner session and handles them accordingly.
func listenToServerEvents(ps provisionSession) {
	provisioner := ps.provisioner
	session := ps.provisioner.Session()
	events := ps.eventSink
	log.Debug("Listening to private server events")
	for {
		select {
		case e := <-session.Events:
			switch e.Type {
			// OAuth events
			case pcommon.EventTypeOAuthStarted:
				log.Debug("OAuth started, waiting for user to complete")
				events.OnPrivateServerEvent(convertStatusToJSON("EventTypeOAuthStarted", "OAuth started, waiting for user to complete"))
				continue
			case pcommon.EventTypeOAuthCancelled:
				log.Debug("OAuth cancelled by user")
				events.OnError(convertErrorToJSON("EventTypeOAuthCancelled", fmt.Errorf("OAuth cancelled by user")))
				return
			case pcommon.EventTypeOAuthError:
				log.Errorf("OAuth failed: %v", e.Error)
				events.OnError(convertErrorToJSON("EventTypeOAuthError", e.Error))
				return
			// Validation events
			case pcommon.EventTypeOAuthCompleted:
				log.Debug("OAuth completed; starting validation")
				ps.authToken = e.Message
				ps.provisioner.Validate(context.Background(), e.Message)
				continue
			case pcommon.EventTypeValidationStarted:
				log.Debug("Validation started")
			case pcommon.EventTypeValidationError:
				log.Errorf("Validation failed: %v %v", e.Error.Error(), e.Message)
				storeSession(&ps)
				events.OnError(convertErrorToJSON("EventTypeValidationError", e.Error))
				continue
			case pcommon.EventTypeValidationCompleted:
				// at this point we have a list of projects and billing accounts
				// present them to the user
				log.Debugf("Provisioning completed successfully: %s", e.Message)
				compartments := provisioner.Compartments()
				if len(compartments) == 0 {
					log.Error("No valid projects found, please check your billing account and permissions")
					events.OnError("No valid projects found, please check your billing account and permissions")
					return
				}
				// if only one compartment, select it by default
				if len(compartments) == 1 {
					// Select account by default
					ps.eventSink.OnPrivateServerEvent(convertStatusToJSON("EventTypeOnlyCompartment", "Found only one compartment, selecting by default"))
					log.Debug("Only one compartment found, selecting by default account")
					accountNames := pcommon.CompartmentNames(compartments)
					name := accountNames[0]
					userCompartment := pcommon.CompartmentByName(compartments, name)
					ps.userCompartment = userCompartment
					//Store the user selected project
					projectList := pcommon.CompartmentEntryIDs(userCompartment.Entries)
					if len(projectList) == 0 {
						err := errors.New("no projects found in the selected compartment")
						log.Error(err)
						events.OnPrivateServerEvent(convertStatusToJSON("EventTypeNoProjects", "No projects found in the selected compartment"))
						return
					}
					selectedProject := projectList[0]
					project := pcommon.CompartmentEntryByID(userCompartment.Entries, selectedProject)
					ps.userProject = project
					ps.userProjectString = selectedProject
					//store session
					storeSession(&ps)
					//Send location list to the event sink
					locationList := pcommon.CompartmentEntryLocations(project)
					// add delay
					time.Sleep(1 * time.Second)
					ps.eventSink.OnPrivateServerEvent(convertStatusToJSON("EventTypeLocations", strings.Join(locationList, ", ")))

				} else {
					ps.CurrentCompartments = compartments
					// update map
					storeSession(&ps)
					log.Debug("Validation completed, ready to create resources")
					//Accounts
					//send account to the client
					accountNames := pcommon.CompartmentNames(compartments)
					log.Debugf("Available accounts: %v", strings.Join(accountNames, ", "))
					events.OnPrivateServerEvent(convertStatusToJSON("EventTypeAccounts", strings.Join(accountNames, ", ")))
				}
				continue
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
				resp := provisionerResponse{}
				err := json.Unmarshal([]byte(e.Message), &resp)

				if err != nil {
					log.Errorf("Error unmarshalling provisioner response: %v", err)
					events.OnError(convertErrorToJSON("EventTypeProvisioningError", err))
					return
				}
				resp.Tag = provisioner.serverName
				resp.Location = provisioner.serverLocation
				mangerErr := AddServerManagerInstance(resp, provisioner)
				if mangerErr != nil {
					log.Errorf("Error adding server manager instance: %v", mangerErr)
					events.OnError(convertErrorToJSON("EventTypeProvisioningError", mangerErr))
					return
				}
				log.Debugf("Server manager instance added successfully: %s", resp.Tag)
				serverInfo, found := ps.manager.GetServerByTag(resp.Tag)
				// add protocol info if found
				if found {
					resp.Protocol = serverInfo.Type
				}
				server, err := json.Marshal(resp)
				if err != nil {
					log.Errorf("Error marshalling server response: %v", err)
					events.OnError(convertErrorToJSON("EventTypeProvisioningError", err))
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
func ValidateSession(ctx context.Context) error {
	ps, err := getSession()
	if err != nil {
		return err
	}
	log.Debug("Validating session")
	ps.provisioner.Validate(ctx, ps.authToken)
	return nil
}

// SelectAccount selects a billing account for the user.
// It updates the session with the selected account and sends the project list to the event sink.
func SelectAccount(name string) error {
	slog.Debug("Selecting account: ", "account", name)
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
	ps.eventSink.OnPrivateServerEvent(convertStatusToJSON("EventTypeProjects", strings.Join(projectList, ", ")))
	return nil
}

// SelectProject selects a project for the user.
func SelectProject(selectedProject string) error {
	ps, err := getSession()
	if err != nil {
		return err
	}
	//Store the user selected project
	project := pcommon.CompartmentEntryByID(ps.userCompartment.Entries, selectedProject)
	ps.userProject = project
	ps.userProjectString = selectedProject
	storeSession(ps)
	//Send location list to the event sink
	locationList := pcommon.CompartmentEntryLocations(project)
	ps.eventSink.OnPrivateServerEvent(convertStatusToJSON("EventTypeLocations", strings.Join(locationList, ", ")))
	return nil
}

// StartDepolyment starts the deployment process for the selected project and location.
func StartDepolyment(selectedLocation, serverName string) error {
	ps, err := getSession()
	if err != nil {
		return err
	}
	log.Debugf("Starting deployment in location: %s name %s", selectedLocation, serverName)
	cloc := pcommon.CompartmentLocationByIdentifier(ps.userProject.Locations, selectedLocation)
	ps.serverName = serverName
	ps.serverLocation = selectedLocation
	storeSession(ps)
	log.Debug("Starting provisioning")
	ps.provisioner.Provision(context.Background(), ps.userProjectString, cloc.GetID())
	return nil
}

// SelectedCertFingerprint sends the selected certificate fingerprint to the channel.
func SelectedCertFingerprint(fp string) {
	select {
	case certFingerprintChan <- fp:
		log.Debugf("Received selected fingerprint: %s", fp)
	default:
		log.Debug("Cert fingerprint channel full or unused")
	}
}

// CancelDeployment cancels the current provisioning session.
func CancelDeployment() error {
	ps, err := getSession()
	if err != nil {
		return err
	}
	log.Debug("Cancelling provisioning")
	ps.provisioner.Session().Cancel()
	ps.eventSink.OnPrivateServerEvent(convertStatusToJSON("EventTypeProvisioningCancelled", "Provisioning cancelled by user"))
	return nil
}

// AddServerManagerInstance adds a server manager instance to the VPN client
// this call radiance and store connect last part
func AddServerManagerInstance(resp provisionerResponse, provisioner *provisionSession) error {
	log.Debug("Adding server manager instance")
	err := provisioner.manager.AddPrivateServer(resp.Tag, resp.ExternalIP, resp.Port, resp.AccessToken, func(ip string, details []servers.CertDetail) *servers.CertDetail {
		if len(details) == 0 {
			return nil
		}
		summaries := make([]certSummary, len(details))
		for i, detail := range details {
			// F5:0E:E4:9A:32:DA:09:B9:4E:E3:5C:08:F1:40:94:AE:9A:31:45:13 - 147.182.166.138 [147.182.166.138]
			summaries[i] = certSummary{
				Fingerprint: detail.Fingerprint,
				Issuer:      detail.Issuer,
				Subject:     detail.Subject,
			}
		}
		jsonBytes, err := json.Marshal(summaries)
		if err != nil {
			log.Errorf("Error marshalling cert details: %v", err)
			provisioner.eventSink.OnError(convertErrorToJSON("EventTypeServerTofuPermissionError", err))
			return nil
		}

		log.Debugf("Available server manager instances: %v", string(jsonBytes))
		provisioner.eventSink.OnPrivateServerEvent(convertStatusToJSON("EventTypeServerTofuPermission", string(jsonBytes)))
		//Now wait for user to select the figerprint
		// Wait for selected fingerprint from Flutter
		selectedFp := <-certFingerprintChan
		for i := range details {
			if details[i].Fingerprint == selectedFp {
				log.Debugf("Matched selected cert: %v", details[i])
				return &details[i]
			}
		}
		log.Error("No certificate matched selected fingerprint")
		return nil
	})
	if err != nil {
		return log.Errorf("Error adding server manager instance: %v", err)
	}
	log.Debugf("Server manager instance added successfully: %s", resp.Tag)
	return nil
}

// AddServerManually adds a server manually to the VPN client.
// It takes the server's IP, port, access token, and tag, along with the VPN client and event listener.
func AddServerManually(ip, port, accessToken, tag string, vpnClient *servers.Manager, events utils.PrivateServerEventListener) error {
	log.Debugf("Adding server manually: %s:%s with tag %s", ip, port, tag)
	portInt, _ := strconv.Atoi(port)
	resp := provisionerResponse{
		ExternalIP:  ip,
		Port:        portInt,
		AccessToken: accessToken,
		Tag:         tag,
	}
	provisionSession := &provisionSession{
		manager:   vpnClient,
		eventSink: events,
	}
	storeSession(provisionSession)
	err := AddServerManagerInstance(resp, provisionSession)
	if err != nil {
		return err
	}
	log.Debugf("Server manager instance added successfully: %s", resp.Tag)
	resp.Tag = tag
	location := getGeoInfo(ip)
	resp.Location = location
	server, jerr := json.Marshal(resp)
	if jerr != nil {
		return log.Errorf("Error marshalling server response: %v", err)
	}
	events.OnPrivateServerEvent(convertStatusToJSON("EventTypeProvisioningCompleted", string(server)))
	return nil
}

func InviteToServerManagerInstance(ip string, port int, accessToken string, inviteName string, vpnClient *servers.Manager) (string, error) {
	log.Debugf("Inviting to server manager instance %s:%d with invite name %s", ip, port, inviteName)
	return vpnClient.InviteToPrivateServer(ip, port, accessToken, inviteName)
}

func RevokeServerManagerInvite(ip string, port int, accessToken string, inviteName string, vpnClient *servers.Manager) error {
	log.Debugf("Revoking invite %s for server %s:%d", inviteName, ip, port)
	return vpnClient.RevokePrivateServerInvite(ip, port, accessToken, inviteName)
}

type geoInfo struct {
	CountryCode string `json:"countryCode"`
	Country     string `json:"country"`
	Region      string `json:"regionName"`
	City        string `json:"city"`
}

// getGeoInfo fetches geographical information for a given IP address using the ip-api.com service.
func getGeoInfo(ip string) string {
	log.Debugf("Fetching geo info for IP: %s", ip)
	resp, err := http.Get("http://ip-api.com/json/" + ip)
	if err != nil {
		log.Errorf("Error fetching geo info: %v", err)
		return ""
	}
	defer resp.Body.Close()

	var info geoInfo
	if err := json.NewDecoder(resp.Body).Decode(&info); err != nil {
		log.Errorf("Error decoding geo info response: %v", err)
		return ""
	}
	log.Debugf("Geo info for IP %s: %+v", ip, info)
	return fmt.Sprintf("%s - %s [%s]", info.Region, info.Country, info.CountryCode)
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
