package client

import (
	"compress/gzip"
	"crypto/x509"
	"errors"
	"io"
	"io/ioutil"
	"net/http"
	"reflect"

	"github.com/getlantern/keyman"
	"github.com/getlantern/yaml"

	"github.com/getlantern/flashlight/client"
)

const (
	httpIfNoneMatch = "If-None-Match"
	httpEtag        = "Etag"
)

var lastCloudConfigETag string

type config struct {
	Client           *client.ClientConfig `yaml:"client"`
	TrustedCAs       []*ca                `yaml:"trustedcas"`
	InstanceId       string               `yaml:"instanceid"`
	FireTweetVersion string               `yaml:"firetweetversion"`
}

var (
	// errFailedConfigRequest is returned when the server replies with a non-200
	// status code to our request for a configuration file.
	errFailedConfigRequest = errors.New(`Could not get configuration file.`)

	// errInvalidConfiguration is returned in case the configuration file is
	// downloaded but has no useful data.
	errInvalidConfiguration = errors.New(`Invalid configuration file.`)

	errConfigurationUnchanged = errors.New(`Configuration remain unchanged.`)
)

const (
	cloudConfigCA = ``
	// URL of the configuration file. Remember to use HTTPs.
	remoteConfigURL = `https://config.getiantem.org/cloud.yaml.gz`
	instanceId      = ``
)

// pullConfigFile attempts to retrieve a configuration file over the network,
// then it decompresses it and returns the file's raw bytes.
func pullConfigFile(cli *http.Client) ([]byte, error) {
	var err error
	var req *http.Request
	var res *http.Response

	if cli == nil {
		return nil, errors.New("Missing HTTP client.")
	}

	if req, err = http.NewRequest("GET", remoteConfigURL, nil); err != nil {
		return nil, err
	}

	if lastCloudConfigETag != "" {
		// Don't bother fetching if unchanged.
		req.Header.Set(httpIfNoneMatch, lastCloudConfigETag)
	}

	if res, err = cli.Do(req); err != nil {
		return nil, err
	}

	// Has changed?
	if res.StatusCode == http.StatusNotModified {
		log.Debugf("Configuration file has not changed since last pull.\n")
		return nil, errConfigurationUnchanged
	}

	// Expecting 200 OK
	if res.StatusCode != http.StatusOK {
		return nil, errFailedConfigRequest
	}

	// Saving ETAG
	lastCloudConfigETag = res.Header.Get(httpEtag)

	// Using a gzip reader as we're getting a compressed file.
	var body io.ReadCloser
	if body, err = gzip.NewReader(res.Body); err != nil {
		return nil, err
	}
	defer func() {
		if err := body.Close(); err != nil {
			log.Debugf("Unable to close body: %v", err)
		}
	}()

	// Uncompressing bytes.
	return ioutil.ReadAll(body)
}

// defaultConfig returns the embedded configuration.
func defaultConfig() *config {
	cfg := &config{
		Client: &client.ClientConfig{
			ChainedServers: defaultChainedServers,
			MasqueradeSets: defaultMasqueradeSets,
		},
		TrustedCAs: defaultTrustedCAs,
	}
	return cfg
}

func (c *config) updateFrom(buf []byte) error {
	var err error
	var newCfg config

	// Attempt to parse configuration file.
	if err = yaml.Unmarshal(buf, &newCfg); err != nil {
		return err
	}

	// Making sure we can actually use this configuration.
	if len(newCfg.Client.MasqueradeSets) > 0 && len(newCfg.TrustedCAs) > 0 {
		if reflect.DeepEqual(newCfg, *c) {
			return errConfigurationUnchanged
		}
		*c = newCfg
		return nil
	}

	return errInvalidConfiguration
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
