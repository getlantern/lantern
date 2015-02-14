package http

import (
	"encoding/json"
	"fmt"
	"github.com/getlantern/flashlight/config"
	"github.com/getlantern/flashlight/util"
	"github.com/getlantern/golog"
	"github.com/getlantern/proxiedsites"
	"github.com/skratchdot/open-golang/open"
	"net/http"
	"reflect"
	"time"

	"github.com/getlantern/tarfs"
)

const (
	UIUrl = "http://%s"
	UIDir = "src/github.com/getlantern/ui/app"
)

var (
	log = golog.LoggerFor("http")
)

type JsonResponse struct {
	Error        string   `json:"Error, omitempty"`
	ProxiedSites []string `json:"ProxiedSites, omitempty"`
	Global       []string `json:"Global, omitempty"`
}

type ProxiedSitesHandler struct {
	ProxiedSites     *proxiedsites.ProxiedSites
	ProxiedSitesChan chan *proxiedsites.Config
}

func sendJsonResponse(w http.ResponseWriter, response *JsonResponse, indent bool) {
	enc := json.NewEncoder(w)
	err := enc.Encode(response)
	if err != nil {
		log.Errorf("error sending json response %v", err)
	}
}

func setResponseHeaders(w http.ResponseWriter) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token")
	w.Header().Set("Access-Control-Allow-Credentials", "True")
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")

}

func (psh ProxiedSitesHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	var response JsonResponse

	setResponseHeaders(w)

	switch r.Method {
	case "OPTIONS":
		// return if it's a preflight OPTIONS request
		// this is mainly for testing the UI when it's running on
		// a separate port
		return
	case "POST":
		// update proxiedsites
		decoder := json.NewDecoder(r.Body)
		var entries []string
		err := decoder.Decode(&entries)
		if err != nil {
			log.Error(err)
			response.Error = fmt.Sprintf("Error decoding proxiedsites: %q", err)
		} else {
			ps := psh.ProxiedSites.UpdateEntries(entries)
			copy := psh.ProxiedSites.Copy()
			log.Debug("Propagating proxiedsites changes..")
			psh.ProxiedSitesChan <- copy
			response.ProxiedSites = ps
		}
	case "GET":
		response.ProxiedSites = psh.ProxiedSites.GetEntries()
		response.Global = psh.ProxiedSites.GetGlobalList()
	default:
		log.Debugf("Received %s", response.Error)
		response.Error = "Invalid proxiedsites HTTP request"
		response.ProxiedSites = nil
	}
	sendJsonResponse(w, &response, false)
}

func servePacFile(w http.ResponseWriter, r *http.Request) {
	pacFile := proxiedsites.GetPacFile()
	http.ServeFile(w, r, pacFile)
}

func UIHttpServer(cfg *config.Config, cfgChan chan *config.Config, proxiedSitesChan chan *proxiedsites.Config) error {

	psh := &ProxiedSitesHandler{
		ProxiedSites:     proxiedsites.New(cfg.Client.ProxiedSites),
		ProxiedSitesChan: proxiedSitesChan,
	}

	r := http.NewServeMux()
	r.Handle("/proxiedsites", psh)

	// poll for config updates to the proxiedsites
	// with this immediately see flashlight.yaml
	// changes in the UI
	go func() {
		for {
			newCfg := <-cfgChan
			clientCfg := newCfg.Client
			if !reflect.DeepEqual(psh.ProxiedSites.GetConfig(), clientCfg.ProxiedSites) {
				log.Debugf("proxiedsites changed in flashlight.yaml..")
				psh.ProxiedSites = proxiedsites.New(newCfg.Client.ProxiedSites)
				psh.ProxiedSites.RefreshEntries()
			}
		}
	}()
	r.HandleFunc("/proxy_on.pac", servePacFile)

	UIDirExists, err := util.DirExists(UIDir)
	if err != nil {
		log.Debugf("UI Directory does not exist %s", err)
	}

	if UIDirExists {
		// UI directory found--serve assets directly from it
		log.Debugf("Serving UI assets from directory %s", UIDir)
		r.Handle("/", http.FileServer(http.Dir(UIDir)))
	} else {
		start := time.Now()
		fs, err := tarfs.New(Resources, "../ui/app")
		if err != nil {
			panic(err)
		}
		delta := time.Now().Sub(start)
		log.Debugf("tarfs startup time: %v", delta)
		r.Handle("/", http.FileServer(fs))
	}

	httpServer := &http.Server{
		Addr:    cfg.UIAddr,
		Handler: r,
	}

	log.Debugf("Starting UI HTTP server at %s", cfg.UIAddr)
	uiAddr := fmt.Sprintf(UIUrl, cfg.UIAddr)

	if cfg.OpenUI {
		err = open.Run(uiAddr)
		if err != nil {
			log.Errorf("Could not open UI! %s", err)
			return err
		}
	}

	err = httpServer.ListenAndServe()
	if err != nil {
		log.Errorf("Could not start HTTP server! %s", err)
		return err
	}
	return err
}
