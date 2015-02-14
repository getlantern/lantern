package http

import (
	"encoding/json"
	"fmt"
	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/flashlight/config"
	"github.com/getlantern/flashlight/util"
	"github.com/getlantern/golog"
	"github.com/getlantern/whitelist"
	"github.com/skratchdot/open-golang/open"
	"net/http"
	"reflect"
	"time"

	"github.com/getlantern/tarfs"
)

const (
	UiUrl = "http://%s"
	UiDir = "src/github.com/getlantern/ui/app"
)

var (
	log = golog.LoggerFor("http")
)

type JsonResponse struct {
	Error     string   `json:"Error, omitempty"`
	Whitelist []string `json:"Whitelist, omitempty"`
	Original  []string `json:"Original, omitempty"`
}

type WhitelistHandler struct {
	http.HandlerFunc
	whitelist *whitelist.Whitelist
	wlChan    chan *whitelist.Config
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

func (wlh WhitelistHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	var response JsonResponse

	setResponseHeaders(w)

	switch r.Method {
	case "OPTIONS":
		// return if it's a preflight OPTIONS request
		// this is mainly for testing the UI when it's running on
		// a separate port
		return
	case "POST":
		// update whitelist
		decoder := json.NewDecoder(r.Body)
		var entries []string
		err := decoder.Decode(&entries)
		if err != nil {
			log.Error(err)
			response.Error = fmt.Sprintf("Error decoding whitelist: %q", err)
		} else {
			wl := wlh.whitelist.UpdateEntries(entries)
			copy := wlh.whitelist.Copy()
			log.Debug("Propagating whitelist changes..")
			wlh.wlChan <- copy
			response.Whitelist = wl
		}
	case "GET":
		response.Whitelist = wlh.whitelist.GetEntries()
	default:
		log.Debugf("Received %s", response.Error)
		response.Error = "Invalid whitelist HTTP request"
		response.Whitelist = nil
	}
	sendJsonResponse(w, &response, false)
}

func servePacFile(w http.ResponseWriter, r *http.Request) {
	pacFile := whitelist.GetPacFile()
	http.ServeFile(w, r, pacFile)
}

func UiHttpServer(cfg *client.ClientConfig, cfgChan chan *config.Config, wlChan chan *whitelist.Config) error {

	wlh := &WhitelistHandler{
		whitelist: whitelist.New(cfg.Whitelist),
		wlChan:    wlChan,
	}

	r := http.NewServeMux()
	r.Handle("/whitelist", wlh)

	// poll for config updates to the whitelist
	// with this immediately see flashlight.yaml
	// changes in the UI
	go func() {
		for {
			newCfg := <-cfgChan
			clientCfg := newCfg.Client
			if !reflect.DeepEqual(wlh.whitelist.GetConfig(), clientCfg.Whitelist) {
				log.Debugf("Whitelist changed in flashlight.yaml..")
				wlh.whitelist = whitelist.New(newCfg.Client.Whitelist)
				wlh.whitelist.RefreshEntries()
			}
		}
	}()
	r.HandleFunc("/proxy_on.pac", servePacFile)

	UiDirExists, err := util.DirExists(UiDir)
	if err != nil {
		log.Debugf("UI Directory does not exist %s", err)
	}

	if UiDirExists {
		// UI directory found--serve assets directly from it
		log.Debugf("Serving UI assets from directory %s", UiDir)
		r.Handle("/", http.FileServer(http.Dir(UiDir)))
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
		Addr:    cfg.UiAddr,
		Handler: r,
	}

	log.Debugf("Starting UI HTTP server at %s", cfg.UiAddr)
	uiAddr := fmt.Sprintf(UiUrl, cfg.UiAddr)

	if cfg.OpenUi {
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
