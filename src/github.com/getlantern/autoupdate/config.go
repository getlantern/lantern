package autoupdate

import (
	"net/http"
)

const (
	updateURI = `http://127.0.0.1:9197/update`
)

// Config struct defines update client configuration.
type Config struct {
	SignerPublicKey []byte
	CurrentVersion  string
	HTTPClient      *http.Client
}
