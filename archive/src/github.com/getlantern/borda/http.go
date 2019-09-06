package borda

import (
	"encoding/json"
	"fmt"
	"net/http"
)

const (
	// ContentType is the key for the Content-Type header
	ContentType = "Content-Type"

	// ContentTypeJSON is the allowed content type
	ContentTypeJSON = "application/json"
)

// ServeHTTP implements the http.Handler interface and supports publishing measurements via HTTP.
func (c *collector) ServeHTTP(resp http.ResponseWriter, req *http.Request) {
	if req.Method != http.MethodPost {
		resp.WriteHeader(http.StatusMethodNotAllowed)
		fmt.Fprintf(resp, "Method %v not allowed\n", req.Method)
		return
	}

	contentType := req.Header.Get(ContentType)
	if contentType != ContentTypeJSON {
		resp.WriteHeader(http.StatusUnsupportedMediaType)
		fmt.Fprintf(resp, "Media type %v unsupported\n", contentType)
		return
	}

	dec := json.NewDecoder(req.Body)
	var measurements []*Measurement
	err := dec.Decode(&measurements)
	if err != nil {
		badRequest(resp, "Error decoding JSON: %v", err)
		return
	}

	if len(measurements) == 0 {
		badRequest(resp, "Please include at least 1 measurement", err)
		return
	}

	for _, m := range measurements {
		if m.Name == "" {
			badRequest(resp, "Missing name")
			return
		}

		if m.Ts.IsZero() {
			badRequest(resp, "Missing ts")
			return
		}

		if m.Values == nil || len(m.Values) == 0 {
			badRequest(resp, "Need at least one value")
			return
		}
	}

	for _, m := range measurements {
		c.Submit(m)
	}

	resp.WriteHeader(http.StatusCreated)
}

func badRequest(resp http.ResponseWriter, msg string, args ...interface{}) {
	resp.WriteHeader(http.StatusBadRequest)
	fmt.Fprintf(resp, msg+"\n", args...)
}
