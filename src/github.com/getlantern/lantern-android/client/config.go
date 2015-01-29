package client

import (
	"compress/gzip"
	"crypto/x509"
	"errors"
	"github.com/getlantern/fronted"
	"github.com/getlantern/keyman"
	"github.com/getlantern/yaml"
	"io"
	"io/ioutil"
	"net/http"
)

type clientCfg struct {
	FrontedServers []frontedServer                  `yaml:"frontedservers"`
	MasqueradeSets map[string][]*fronted.Masquerade `yaml:"masqueradesets"`
}

// config provides client configuration.
type config struct {
	Client     clientCfg `yaml:"client"`
	TrustedCAs []*ca     `yaml:"trustedcas"`
}

var (
	// errFailedConfigRequest is returned when the server replies with a non-200
	// status code to our request for a configuration file.
	errFailedConfigRequest = errors.New(`Could not get configuration file.`)

	// errInvalidConfiguration is returned in case the configuration file is
	// downloaded but has no useful data.
	errInvalidConfiguration = errors.New(`Invalid configuration file.`)
)

const (
	// URL of the configuration file. Remember to use HTTPs.
	remoteConfigURL = `https://s3.amazonaws.com/lantern_config/cloud.1.6.0.yaml.gz`
)

// pullConfigFile attempts to retrieve a configuration file over the network,
// then it decompresses it and returns the file's raw bytes.
func pullConfigFile() ([]byte, error) {
	var err error
	var res *http.Response

	// Issuing a post request to download configuration file.
	if res, err = http.Get(remoteConfigURL); err != nil {
		return nil, err
	}

	// Expecting 200 OK
	if res.StatusCode != http.StatusOK {
		return nil, errFailedConfigRequest
	}

	// Using a gzip reader as we're getting a compressed file.
	var body io.ReadCloser
	if body, err = gzip.NewReader(res.Body); err != nil {
		return nil, err
	}

	// Returning uncompressed bytes.
	return ioutil.ReadAll(body)
}

// defaultConfig returns the embedded configuration.
func defaultConfig() *config {
	cfg := &config{
		Client: clientCfg{
			FrontedServers: defaultFrontedServerList,
			MasqueradeSets: defaultMasqueradeSets,
		},
		TrustedCAs: defaultTrustedCAs,
	}
	return cfg
}

// getConfig attempts to provide a
func getConfig() (*config, error) {
	var err error
	var buf []byte

	var cfg config

	// Attempt to download configuration file.
	if buf, err = pullConfigFile(); err != nil {
		return defaultConfig(), err
	}

	// Attempt to parse configuration file.
	if err = yaml.Unmarshal(buf, &cfg); err != nil {
		return defaultConfig(), err
	}

	// Making sure we can actually use this configuration.
	if len(cfg.Client.FrontedServers) > 0 && len(cfg.Client.MasqueradeSets) > 0 && len(cfg.TrustedCAs) > 0 {
		return &cfg, nil
	}

	return defaultConfig(), errInvalidConfiguration
}

func (c *config) getTrustedCerts() []string {
	certs := make([]string, 0, len(c.TrustedCAs))

	for _, ca := range c.TrustedCAs {
		certs = append(certs, ca.Cert)
	}

	return certs
}

func (c *config) getTrustedCertPool() (certPool *x509.CertPool, err error) {
	trustedCerts := c.getTrustedCerts()

	if certPool, err = keyman.PoolContainingCerts(trustedCerts...); err != nil {
		return nil, err
	}

	return certPool, nil
}
