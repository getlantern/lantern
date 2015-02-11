package http

import (
	"encoding/json"
	"fmt"
	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/flashlight/util"
	"github.com/getlantern/golog"
	"github.com/getlantern/whitelist"
	"github.com/skratchdot/open-golang/open"
	"net/http"
)

const (
	UIDir  = "src/github.com/getlantern/ui/app"
	UIAddr = "http://127.0.0.1%s"
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
	Whitelist *whitelist.Whitelist
}

func sendJsonResponse(w http.ResponseWriter, response *JsonResponse, indent bool) {

	enc := json.NewEncoder(w)
	err := enc.Encode(response)
	if err != nil {
		log.Fatalf("error sending json response %v", err)
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
		/* return if it's a preflight OPTIONS request
		* this is mainly for testing the UI when it's running on
		* a separate port
		 */
		return
	case "POST":
		/* update whitelist */
		log.Debug("Updating whitelist entries...")
		decoder := json.NewDecoder(r.Body)
		var entries []string
		err := decoder.Decode(&entries)
		util.Check(err, log.Error, "Error decoding whitelist entries")
		wl := whitelist.NewWithEntries(entries)
		response.Whitelist = wl.Copy()
	case "GET":
		log.Debug("Retrieving whitelist...")
		response.Whitelist = wlh.Whitelist.Copy()
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

func ListenAndServe(cfg *client.ClientConfig) {
	r := http.NewServeMux()
	r.Handle("/whitelist", &WhitelistHandler{
		Whitelist: cfg.Whitelist,
	})
	r.HandleFunc("/proxy_on.pac", servePacFile)

	UIDirExists, err := util.DirExists(UIDir)
	if err != nil {
		log.Debugf("UI Directory does not exist %s", err)
	}

	if UIDirExists {
		/* UI directory found--serve assets directly from it */
		log.Debugf("Serving UI assets from directory %s", UIDir)
		r.Handle("/", http.FileServer(http.Dir(UIDir)))
	} else {
		assetFS()
	}

	httpServer := &http.Server{
		Addr:    cfg.HttpAddr,
		Handler: r,
		//ReadTimeout:  ReadTimeout,
		//WriteTimeout: WriteTimeout,
	}

	go func() {
		log.Debugf("Starting UI HTTP server at %s", cfg.HttpAddr)
		uiAddr := fmt.Sprintf(UIAddr, cfg.HttpAddr)
		err := open.Run(uiAddr)
		if err != nil {
			log.Errorf("Could not open UI! %s", err)
		}
	}()

	err = httpServer.ListenAndServe()
	if err != nil {
		log.Errorf("Could not start HTTP server! %s", err)
	}
}
