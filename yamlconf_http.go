package yamlconf

import (
	"fmt"
	"io/ioutil"
	"net/http"
	"time"

	"github.com/getlantern/pathreflect"
	. "gopkg.in/getlantern/waitforserver.v1"
	"gopkg.in/getlantern/yaml.v1"
)

const (
	POST   = "POST"
	DELETE = "DELETE"

	BadRequest       = 400
	MethodNotAllowed = 405
)

func (m *Manager) startConfigServer() error {
	log.Debugf("Starting config server at: %s", m.ConfigServerAddr)

	s := &http.Server{
		Addr:    m.ConfigServerAddr,
		Handler: m,
	}

	go func() {
		err := s.ListenAndServe()
		if err != nil {
			log.Errorf("Unable to start config server: %s", err)
		}
	}()

	return WaitForServer("tcp", m.ConfigServerAddr, 10*time.Second)
}

func (m *Manager) ServeHTTP(resp http.ResponseWriter, req *http.Request) {
	defer req.Body.Close()

	if len(req.URL.Path) < 2 {
		fail(resp, "Invalid path")
	}
	path := pathreflect.Parse(req.URL.Path[1:])

	switch req.Method {
	case POST:
		body, err := ioutil.ReadAll(req.Body)
		if err != nil {
			log.Debugf("Error reading post to config server: %s", err)
			fail(resp, "Unable to read request body")
			return
		}

		err = m.Update(func(orig Config) error {
			defer func() {
				if r := recover(); r != nil {
					log.Errorf("Panic on updating %s: %s", path, r)
				}
			}()

			fragment, err := path.Get(orig)
			if err != nil {
				return fmt.Errorf("Unable to get current value at path %s: %s", path, err)
			}

			err = yaml.Unmarshal(body, fragment)
			if err != nil {
				return fmt.Errorf("Unable to unmarshal yaml fragment from body %s: %s", string(body), err)
			}

			return path.Set(orig, fragment)
		})

		if err != nil {
			log.Debugf("Unable to update config: %s", err)
			fail(resp, "Unable to update config")
			return
		}
	case DELETE:
		err := m.Update(func(orig Config) error {
			defer func() {
				if r := recover(); r != nil {
					log.Errorf("Panic on clearing %s: %s", path, r)
				}
			}()

			return path.Clear(orig)
		})

		if err != nil {
			log.Debugf("Unable to update config: %s", err)
			fail(resp, "Unable to update config")
			return
		}
	default:
		resp.WriteHeader(MethodNotAllowed)
	}
}

func fail(resp http.ResponseWriter, msg string) {
	resp.Header().Set("Content-Type", "text/plain")
	resp.WriteHeader(BadRequest)
	resp.Write([]byte(msg))
}
