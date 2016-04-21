package main

import (
	"encoding/json"
	"flag"
	"net/http"
	"os"
	"time"

	"github.com/getlantern/autoupdate-server/server"
	"github.com/getlantern/golog"
)

var (
	flagPrivateKey         = flag.String("k", "", "Path to private key.")
	flagLocalAddr          = flag.String("l", ":6868", "Local bind address.")
	flagPublicAddr         = flag.String("p", "http://127.0.0.1:6868/", "Public address.")
	flagGithubOrganization = flag.String("o", "getlantern", "Github organization.")
	flagGithubProject      = flag.String("n", "lantern", "Github project name.")
	flagHelp               = flag.Bool("h", false, "Shows help.")
)

var (
	log            = golog.LoggerFor("autoupdate-server")
	releaseManager *server.ReleaseManager
)

type updateHandler struct {
}

// updateAssets checks for new assets released on the github releases page.
func updateAssets() error {
	log.Debug("Updating assets...")
	if err := releaseManager.UpdateAssetsMap(); err != nil {
		return err
	}
	return nil
}

// backgroundUpdate periodically looks for releases.
func backgroundUpdate() {
	for {
		time.Sleep(githubRefreshTime)
		// Updating assets...
		if err := updateAssets(); err != nil {
			log.Debugf("updateAssets: %s", err)
		}
	}
}

func (u *updateHandler) closeWithStatus(w http.ResponseWriter, status int) {
	w.WriteHeader(status)
	if _, err := w.Write([]byte(http.StatusText(status))); err != nil {
		log.Debugf("Unable to write status: %v", err)
	}
}

func (u *updateHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	var err error
	var res *server.Result

	if r.Method == "POST" {
		defer func() {
			if err := r.Body.Close(); err != nil {
				log.Debugf("Unable to close request body: %v", err)
			}
		}()

		var params server.Params
		decoder := json.NewDecoder(r.Body)

		if err = decoder.Decode(&params); err != nil {
			u.closeWithStatus(w, http.StatusBadRequest)
			return
		}

		if res, err = releaseManager.CheckForUpdate(&params); err != nil {
			log.Debugf("CheckForUpdate failed with error: %q", err)
			if err == server.ErrNoUpdateAvailable {
				log.Debugf("Got query from client %q/%q, no update available.", params.AppVersion, params.OS)
				u.closeWithStatus(w, http.StatusNoContent)
				return
			}
			log.Debugf("Got query from client %q/%q: %q.", err)
			u.closeWithStatus(w, http.StatusExpectationFailed)
			return
		}

		log.Debugf("Got query from client %q/%q, resolved to upgrade to %q using %q strategy.", params.AppVersion, params.OS, res.Version, res.PatchType)

		if res.PatchURL != "" {
			res.PatchURL = *flagPublicAddr + res.PatchURL
		}

		var content []byte

		if content, err = json.Marshal(res); err != nil {
			u.closeWithStatus(w, http.StatusInternalServerError)
			return
		}

		w.WriteHeader(http.StatusOK)
		w.Header().Set("Content-Type", "application/json")
		if _, err := w.Write(content); err != nil {
			log.Debugf("Unable to write response: %v", err)
		}
		return
	}
	u.closeWithStatus(w, http.StatusNotFound)
	return
}

func main() {

	// Parsing flags
	flag.Parse()

	if *flagHelp || *flagPrivateKey == "" {
		flag.Usage()
		os.Exit(0)
	}

	server.SetPrivateKey(*flagPrivateKey)

	// Creating release manager.
	log.Debug("Starting release manager.")
	releaseManager = server.NewReleaseManager(*flagGithubOrganization, *flagGithubProject)
	// Getting assets...
	if err := updateAssets(); err != nil {
		// In this case we will not be able to continue.
		log.Fatal(err)
	}

	// Setting a goroutine for pulling updates periodically
	go backgroundUpdate()

	mux := http.NewServeMux()

	mux.Handle("/update", new(updateHandler))
	mux.Handle("/patches/", http.StripPrefix("/patches/", http.FileServer(http.Dir(localPatchesDirectory))))

	srv := http.Server{
		Addr:    *flagLocalAddr,
		Handler: mux,
	}

	log.Debugf("Starting up HTTP server at %s.", *flagLocalAddr)

	if err := srv.ListenAndServe(); err != nil {
		log.Fatalf("ListenAndServe: ", err)
	}

}
