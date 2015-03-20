package main

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/getlantern/autoupdate-server/server"
	"github.com/getlantern/golog"
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

func init() {
	// Creating release manager.
	log.Debug("Starting release manager.")
	releaseManager = server.NewReleaseManager(githubNamespace, githubRepo)
	// Getting assets...
	if err := updateAssets(); err != nil {
		// In this case we will not be able to continue.
		log.Fatal(err)
	}
	// Setting a goroutine for pulling updates periodically
	go backgroundUpdate()
}

func (u *updateHandler) closeWithStatus(w http.ResponseWriter, status int) {
	w.WriteHeader(status)
	w.Write([]byte(http.StatusText(status)))
}

func (u *updateHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	var err error
	var res *server.Result

	if r.Method == "POST" {
		defer r.Body.Close()

		var params server.Params
		decoder := json.NewDecoder(r.Body)

		if err = decoder.Decode(&params); err != nil {
			u.closeWithStatus(w, http.StatusBadRequest)
			return
		}

		if res, err = releaseManager.CheckForUpdate(&params); err != nil {
			log.Debugf("CheckForUpdate failed with error: %q", err)
			if err == server.ErrNoUpdateAvailable {
				u.closeWithStatus(w, http.StatusNoContent)
			}
			u.closeWithStatus(w, http.StatusExpectationFailed)
			return
		}

		if res.PatchURL != "" {
			res.PatchURL = publicAddr + res.PatchURL
		}

		var content []byte

		if content, err = json.Marshal(res); err != nil {
			u.closeWithStatus(w, http.StatusInternalServerError)
			return
		}

		w.WriteHeader(http.StatusOK)
		w.Header().Set("Content-Type", "application/json")
		w.Write(content)
		return
	}
	u.closeWithStatus(w, http.StatusNotFound)
	return
}

func main() {

	mux := http.NewServeMux()

	mux.Handle("/update", new(updateHandler))
	mux.Handle("/patches/", http.StripPrefix("/patches/", http.FileServer(http.Dir(patchesDirectory))))

	srv := http.Server{
		Addr:    listenAddr,
		Handler: mux,
	}

	log.Debugf("Starting up HTTP server at %s.", listenAddr)

	if err := srv.ListenAndServe(); err != nil {
		log.Fatalf("ListenAndServe: ", err)
	}

}
