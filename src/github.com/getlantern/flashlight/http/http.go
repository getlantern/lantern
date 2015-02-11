package http

import (
	"encoding/json"
	"github.com/getlantern/flashlight/util"
	"github.com/getlantern/golog"
	"github.com/getlantern/whitelist"
	"github.com/gorilla/mux"
	"net/http"
	"time"

	"github.com/getlantern/tarfs"
)

var (
	log = golog.LoggerFor("http")
)

type JsonResponse struct {
	Error     string   `json:"Error, omitempty"`
	Whitelist []string `json:"Whitelist, omitempty"`
	Original  []string `json:"Original, omitempty"`
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

func WhitelistHandler(w http.ResponseWriter, r *http.Request) {
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
		wl := whitelist.New()
		response.Original = whitelist.LoadDefaultList()
		response.Whitelist = wl.Copy()
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

func Start(httpAddr string) {
	r := mux.NewRouter()
	r.HandleFunc("/whitelist", WhitelistHandler)
	r.HandleFunc("/proxy_on.pac", servePacFile)

	start := time.Now()
	fs, err := tarfs.New(Data, "../ui/app")
	if err != nil {
		panic(err)
	}
	delta := time.Now().Sub(start)
	log.Debugf("tarfs startup time: %v", delta)
	r.PathPrefix("/").Handler(http.FileServer(fs)).Methods("GET")
	openUI()
	http.Handle("/", r)

	http.ListenAndServe(httpAddr, nil)
	/*err := pacon.PacOn("localhost:8000/proxy_on.pac")
	if err != nil {
		log.Errorf("Error set proxy: %s\n", err)
		return
	}*/
}
