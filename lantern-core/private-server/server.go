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

	"github.com/getlantern/radiance/servers"

	pcommon "github.com/getlantern/lantern-server-provisioner/common"
	"github.com/getlantern/lantern-server-provisioner/digitalocean"
	"github.com/getlantern/lantern-server-provisioner/gcp"
	"github.com/getlantern/lantern/lantern-core/utils"
)

var (
	provisionerMutex sync.Mutex
	sessions         = sync.Map{}
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

// storeSession stores the provision session in a global map.
func storeSession(ps *provisionSession) {
	provisionerMutex.Lock()
	defer provisionerMutex.Unlock()
	slog.Debug("Storing provision session in sessions map")
	sessions.Store("provisioner", ps)
}

// getSession retrieves the provision session from the global map.
func getSession() (*provisionSession, error) {
	provisionerMutex.Lock()
	defer provisionerMutex.Unlock()
	val, ok := sessions.Load("provisioner")
	slog.Debug("Getting provision session from sessions map")
	if !ok {
		slog.Error("No active session found")
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
		slog.Error("Failed to start DigitalOcean provisioner")
		return fmt.Errorf("failed to start DigitalOcean provisioner")
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
		slog.Error("Failed to start Google Cloud provisioner")
		return fmt.Errorf("failed to start Google Cloud provisioner")
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
	slog.Debug("Listening to private server events")
	for {
		select {
		case e := <-session.Events:
			switch e.Type {
			// OAuth events
			case pcommon.EventTypeOAuthStarted:
				slog.Debug("OAuth started, waiting for user to complete")
				events.OnPrivateServerEvent(convertStatusToJSON("EventTypeOAuthStarted", "OAuth started, waiting for user to complete"))
				continue
			case pcommon.EventTypeOAuthCancelled:
				slog.Debug("OAuth cancelled by user")
				events.OnError(convertErrorToJSON("EventTypeOAuthCancelled", fmt.Errorf("OAuth cancelled by user")))
				return
			case pcommon.EventTypeOAuthError:
				slog.Error("OAuth failed", slog.Any("error", e.Error))
				events.OnError(convertErrorToJSON("EventTypeOAuthError", e.Error))
				return
			// Validation events
			case pcommon.EventTypeOAuthCompleted:
				slog.Debug("OAuth completed; starting validation")
				ps.authToken = e.Message
				ps.provisioner.Validate(context.Background(), e.Message)
				continue
			case pcommon.EventTypeValidationStarted:
				slog.Debug("Validation started")
			case pcommon.EventTypeValidationError:
				slog.Error("Validation failed", slog.Any("error", e.Error), slog.String("message", e.Message))
				storeSession(&ps)
				events.OnError(convertErrorToJSON("EventTypeValidationError", e.Error))
				continue
			case pcommon.EventTypeValidationCompleted:
				// at this point we have a list of projects and billing accounts
				// present them to the user
				slog.Debug("Provisioning completed successfully", slog.String("message", e.Message))
				compartments := provisioner.Compartments()
				if len(compartments) == 0 {
					slog.Error("No valid projects found, please check your billing account and permissions")
					events.OnError("No valid projects found, please check your billing account and permissions")
					return
				}
				// if only one compartment, select it by default
				if len(compartments) == 1 {
					// Select account by default
					ps.eventSink.OnPrivateServerEvent(convertStatusToJSON("EventTypeOnlyCompartment", "Found only one compartment, selecting by default"))
					slog.Debug("Only one compartment found, selecting by default account")
					accountNames := pcommon.CompartmentNames(compartments)
					name := accountNames[0]
					userCompartment := pcommon.CompartmentByName(compartments, name)
					ps.userCompartment = userCompartment
					// Store the user selected project
					projectList := pcommon.CompartmentEntryIDs(userCompartment.Entries)
					if len(projectList) == 0 {
						err := errors.New("no projects found in the selected compartment")
						slog.Error("No projects found in the selected compartment", slog.Any("error", err))
						events.OnPrivateServerEvent(convertStatusToJSON("EventTypeNoProjects", "No projects found in the selected compartment"))
						return
					}
					selectedProject := projectList[0]
					project := pcommon.CompartmentEntryByID(userCompartment.Entries, selectedProject)
					ps.userProject = project
					ps.userProjectString = selectedProject
					// store session
					storeSession(&ps)
					// Send location list to the event sink
					locationList := pcommon.CompartmentEntryLocations(project)
					// add delay
					time.Sleep(1 * time.Second)
					ps.eventSink.OnPrivateServerEvent(convertStatusToJSON("EventTypeLocations", strings.Join(locationList, ", ")))

				} else {
					ps.CurrentCompartments = compartments
					// update map
					storeSession(&ps)
					slog.Debug("Validation completed, ready to create resources")
					// Accounts
					// send account to the client
					accountNames := pcommon.CompartmentNames(compartments)
					slog.Debug("Available accounts", slog.Any("accountNames", accountNames))
					events.OnPrivateServerEvent(convertStatusToJSON("EventTypeAccounts", strings.Join(accountNames, ", ")))
				}
				continue
			case pcommon.EventTypeProvisioningStarted:
				slog.Debug("Provisioning started")
				events.OnPrivateServerEvent(convertStatusToJSON("EventTypeProvisioningStarted", "Provisioning started, please wait..."))
			case pcommon.EventTypeProvisioningCompleted:
				slog.Debug("Provisioning completed successfully", slog.String("message", e.Message))
				// get session
				provisioner, perr := getSession()
				if perr != nil {
					events.OnError(convertErrorToJSON("EventTypeProvisioningError", perr))
				}
				// we have the response, now we can add the server manager instance
				resp := provisionerResponse{}
				err := json.Unmarshal([]byte(e.Message), &resp)
				if err != nil {
					slog.Error("Error unmarshalling provisioner response", slog.Any("error", err))
					events.OnError(convertErrorToJSON("EventTypeProvisioningError", err))
					return
				}
				resp.Tag = provisioner.serverName
				resp.Location = provisioner.serverLocation
				mangerErr := AddServerManagerInstance(resp, provisioner)
				if mangerErr != nil {
					slog.Error("Error adding server manager instance", slog.Any("error", mangerErr))
					events.OnError(convertErrorToJSON("EventTypeProvisioningError", mangerErr))
					return
				}
				slog.Debug("Server manager instance added successfully", slog.String("tag", resp.Tag))
				serverInfo, found := ps.manager.GetServerByTag(resp.Tag)
				// add protocol info if found
				if found {
					resp.Protocol = serverInfo.Type
				}
				server, err := json.Marshal(resp)
				if err != nil {
					slog.Error("Error marshalling server response", slog.Any("error", err))
					events.OnError(convertErrorToJSON("EventTypeProvisioningError", err))
				}

				events.OnPrivateServerEvent(convertStatusToJSON("EventTypeProvisioningCompleted", string(server)))
				return
			case pcommon.EventTypeProvisioningError:
				slog.Error("Provisioning failed", slog.Any("error", e.Error))
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
	slog.Debug("Validating session")
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
	// Store the user selected compartment
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
	// Store the user selected project
	project := pcommon.CompartmentEntryByID(ps.userCompartment.Entries, selectedProject)
	ps.userProject = project
	ps.userProjectString = selectedProject
	storeSession(ps)
	// Send location list to the event sink
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
	slog.Debug("Starting deployment", slog.String("location", selectedLocation), slog.String("serverName", serverName))
	cloc := pcommon.CompartmentLocationByIdentifier(ps.userProject.Locations, selectedLocation)
	ps.serverName = serverName
	ps.serverLocation = selectedLocation
	storeSession(ps)
	slog.Debug("Starting provisioning")
	ps.provisioner.Provision(context.Background(), ps.userProjectString, cloc.GetID())
	return nil
}

// CancelDeployment cancels the current provisioning session.
func CancelDeployment() error {
	ps, err := getSession()
	if err != nil {
		return err
	}
	slog.Debug("Cancelling provisioning")
	ps.provisioner.Session().Cancel()
	ps.eventSink.OnPrivateServerEvent(convertStatusToJSON("EventTypeProvisioningCancelled", "Provisioning cancelled by user"))
	return nil
}

// AddServerManagerInstance adds a server manager instance to the VPN client
// this call radiance and store connect last part
func AddServerManagerInstance(resp provisionerResponse, provisioner *provisionSession) error {
	slog.Debug("Adding server manager instance")
	time.Sleep(1 * time.Second)
	err := provisioner.manager.AddPrivateServer(resp.Tag, resp.ExternalIP, resp.Port, resp.AccessToken)
	if err != nil {
		slog.Error("Error adding server manager instance", slog.Any("error", err))
		return err
	}
	slog.Debug("Server manager instance added successfully", slog.String("tag", resp.Tag))
	return nil
}

// AddServerManually adds a server manually to the VPN client.
// It takes the server's IP, port, access token, and tag, along with the VPN client and event listener.
func AddServerManually(ip, port, accessToken, tag string, vpnClient *servers.Manager, events utils.PrivateServerEventListener) error {
	slog.Debug("Adding server manually", slog.String("ip", ip), slog.String("port", port), slog.String("tag", tag))
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
	slog.Debug("Server manager instance added successfully", slog.String("tag", resp.Tag))
	resp.Tag = tag
	location := getGeoInfo(ip)
	resp.Location = location
	server, jerr := json.Marshal(resp)
	if jerr != nil {
		slog.Error("Error marshalling server response", slog.Any("error", jerr))
		return jerr
	}
	events.OnPrivateServerEvent(convertStatusToJSON("EventTypeProvisioningCompleted", string(server)))
	return nil
}

func InviteToServerManagerInstance(ip string, port int, accessToken string, inviteName string, vpnClient *servers.Manager) (string, error) {
	slog.Debug("Inviting to server manager instance", slog.String("ip", ip), slog.Int("port", port), slog.String("inviteName", inviteName))
	return vpnClient.InviteToPrivateServer(ip, port, accessToken, inviteName)
}

func RevokeServerManagerInvite(ip string, port int, accessToken string, inviteName string, vpnClient *servers.Manager) error {
	slog.Debug("Revoking invite", slog.String("inviteName", inviteName), slog.String("ip", ip), slog.Int("port", port))
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
	slog.Debug("Fetching geo info for IP", slog.String("ip", ip))
	resp, err := http.Get("http://ip-api.com/json/" + ip)
	if err != nil {
		slog.Error("Error fetching geo info", slog.Any("error", err))
		return ""
	}
	defer resp.Body.Close()

	var info geoInfo
	if err := json.NewDecoder(resp.Body).Decode(&info); err != nil {
		slog.Error("Error decoding geo info response", slog.Any("error", err))
		return ""
	}
	slog.Debug("Geo info for IP", slog.String("ip", ip), slog.Any("info", info))
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
