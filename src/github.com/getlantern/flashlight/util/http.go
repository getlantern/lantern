package util

import (
	"crypto/tls"
	"errors"
	"fmt"
	"net"
	"net/http"
	"net/url"
	"sync"
	"time"

	"github.com/getlantern/eventual"
	"github.com/getlantern/fronted"
	"github.com/getlantern/golog"
	"github.com/getlantern/keyman"
)

var (
	log = golog.LoggerFor("flashlight.util")

	// This is for doing direct domain fronting if necessary. We store this as
	// an instance variable because it caches TLS session configs.
	direct = fronted.NewDirect()
)

// HTTPFetcher is a simple interface for types that are able to fetch data over HTTP.
type HTTPFetcher interface {
	Do(req *http.Request) (*http.Response, error)
}

func success(resp *http.Response) bool {
	return resp.StatusCode > 199 && resp.StatusCode < 400
}

// NewChainedAndFronted creates a new struct for accessing resources using chained
// and direct fronted servers in parallel.
func NewChainedAndFronted(proxyAddrFN eventual.Getter) *chainedAndFronted {
	cf := &chainedAndFronted{proxyAddrFN: proxyAddrFN}
	cf.setFetcher(&dualFetcher{cf})
	return cf
}

// ChainedAndFronted fetches HTTP data in parallel using both chained and fronted
// servers.
type chainedAndFronted struct {
	proxyAddrFN eventual.Getter
	_fetcher    HTTPFetcher
	mu          sync.RWMutex
}

func (cf *chainedAndFronted) getFetcher() HTTPFetcher {
	cf.mu.RLock()
	result := cf._fetcher
	cf.mu.RUnlock()
	return result
}

func (cf *chainedAndFronted) setFetcher(fetcher HTTPFetcher) {
	cf.mu.Lock()
	cf._fetcher = fetcher
	cf.mu.Unlock()
}

// Do will attempt to execute the specified HTTP request using only a chained fetcher
func (cf *chainedAndFronted) Do(req *http.Request) (*http.Response, error) {
	resp, err := cf.getFetcher().Do(req)
	if err != nil {
		// If there's an error, switch back to using the dual fetcher.
		cf.setFetcher(&dualFetcher{cf})
	} else if !success(resp) {
		cf.setFetcher(&dualFetcher{cf})
	}
	return resp, err
}

type chainedFetcher struct {
	proxyAddrFN eventual.Getter
}

// Do will attempt to execute the specified HTTP request using only a chained fetcher
func (cf *chainedFetcher) Do(req *http.Request) (*http.Response, error) {
	log.Debugf("Using chained fronter")
	if client, err := HTTPClient("", cf.proxyAddrFN); err != nil {
		log.Errorf("Could not create HTTP client: %v", err)
		return nil, err
	} else {
		return client.Do(req)
	}
}

type dualFetcher struct {
	cf *chainedAndFronted
}

// Do will attempt to execute the specified HTTP request using both
// chained and fronted servers, simply returning the first response to
// arrive. Callers MUST use the Lantern-Fronted-URL HTTP header to
// specify the fronted URL to use.
func (df *dualFetcher) Do(req *http.Request) (*http.Response, error) {
	log.Debugf("Using dual fronter")
	frontedUrl := req.Header.Get("Lantern-Fronted-URL")
	req.Header.Del("Lantern-Fronted-URL")

	if frontedUrl == "" {
		return nil, errors.New("Callers MUST specify the fronted URL in the Lantern-Fronted-URL header")
	}
	responses := make(chan *http.Response, 2)
	errs := make(chan error, 2)

	request := func(client HTTPFetcher, req *http.Request) error {
		if resp, err := client.Do(req); err != nil {
			log.Errorf("Could not complete request with: %v, %v", frontedUrl, err)
			errs <- err
			return err
		} else {
			if success(resp) {
				log.Debugf("Got successful HTTP call!")
				responses <- resp
				return nil
			} else {
				// If the local proxy can't connect to any upstread proxies, for example,
				// it will return a 502.
				err := fmt.Errorf("Bad response code: %v", resp.StatusCode)
				errs <- err
				return err
			}
		}
	}

	go func() {
		if req, err := http.NewRequest("GET", frontedUrl, nil); err != nil {
			log.Errorf("Could not create request for: %v, %v", frontedUrl, err)
			errs <- err
		} else {
			log.Debug("Sending request via DDF")
			if err := request(direct, req); err != nil {
				log.Errorf("Fronted request failed: %v", err)
			} else {
				log.Debug("Fronted request succeeded")
			}
		}
	}()
	go func() {
		if client, err := HTTPClient("", df.cf.proxyAddrFN); err != nil {
			log.Errorf("Could not create HTTP client: %v", err)
			errs <- err
		} else {
			log.Debug("Sending chained request")
			if err := request(client, req); err != nil {
				log.Errorf("Chained request failed %v", err)
			} else {
				log.Debug("Switching to chained fronter for future requests since it succeeded")
				df.cf.setFetcher(&chainedFetcher{})
			}
		}
	}()

	// Create channels for the final response or error. The response channel will be filled
	// in the case of any successful response as well as a non-error response for the second
	// response received. The error channel will only be filled if the first response is
	// unsuccessful and the second is an error.
	finalResponseCh := make(chan *http.Response, 1)
	finalErrorCh := make(chan error, 1)

	go readResponses(finalResponseCh, responses, finalErrorCh, errs)

	select {
	case resp := <-finalResponseCh:
		return resp, nil
	case err := <-finalErrorCh:
		return nil, err
	}
}

func readResponses(finalResponse chan *http.Response, responses chan *http.Response, finalErr chan error, errs chan error) {
	select {
	case resp := <-responses:
		if success(resp) {
			log.Debug("Got good first response")
			finalResponse <- resp

			// Just ignore the second response, but still process it.
			select {
			case resp := <-responses:
				log.Debug("Closing second response body")
				_ = resp.Body.Close()
				return
			case <-errs:
				log.Debug("Ignoring error on second response")
				return
			}
		} else {
			log.Debugf("Got bad first response -- wait for second")
			_ = resp.Body.Close()
			// Just use whatever we get from the second response.
			select {
			case resp := <-responses:
				finalResponse <- resp
			case err := <-errs:
				finalErr <- err
			}
		}
	case err := <-errs:
		log.Debugf("Got an error: %v", err)
		// Just use whatever we get from the second response.
		select {
		case resp := <-responses:
			finalResponse <- resp
		case err := <-errs:
			finalErr <- err
		}
	}
}

// PersistentHTTPClient creates an http.Client that persists across requests.
// If rootCA is specified, the client will validate the server's certificate
// on TLS connections against that RootCA. If proxyAddr is specified, the client
// will proxy through the given http proxy.
func PersistentHTTPClient(rootCA string, proxyAddrFN eventual.Getter) (*http.Client, error) {
	return httpClient(rootCA, proxyAddrFN, true)
}

// HTTPClient creates an http.Client. If rootCA is specified, the client will
// validate the server's certificate on TLS connections against that RootCA. If
// proxyAddr is specified, the client will proxy through the given http proxy.
func HTTPClient(rootCA string, proxyAddrFN eventual.Getter) (*http.Client, error) {
	return httpClient(rootCA, proxyAddrFN, false)
}

// httpClient creates an http.Client. If rootCA is specified, the client will
// validate the server's certificate on TLS connections against that RootCA. If
// proxyAddr is specified, the client will proxy through the given http proxy.
func httpClient(rootCA string, proxyAddrFN eventual.Getter, persistent bool) (*http.Client, error) {
	log.Debugf("Creating new HTTPClient with proxyAddrFN: %v", proxyAddrFN)

	tr := &http.Transport{
		Dial: (&net.Dialer{
			Timeout:   60 * time.Second,
			KeepAlive: 30 * time.Second,
		}).Dial,
		TLSHandshakeTimeout: 10 * time.Second,

		// This method is typically used for creating a one-off HTTP client
		// that we don't want to keep around for future calls, making
		// persistent connections a potential source of file descriptor
		// leaks. Note the name of this variable is misleading -- it would
		// be clearer to call it DisablePersistentConnections -- i.e. it has
		// nothing to do with TCP keep alives along the lines of the KeepAlive
		// variable in net.Dialer.
		DisableKeepAlives: !persistent,
	}

	if rootCA != "" {
		caCert, err := keyman.LoadCertificateFromPEMBytes([]byte(rootCA))
		if err != nil {
			return nil, fmt.Errorf("Unable to decode rootCA: %s", err)
		}
		tr.TLSClientConfig = &tls.Config{
			RootCAs: caCert.PoolContainingCert(),
		}
	}

	if proxyAddrFN != nil {
		log.Debug("Waiting for proxy server to come online")
		proxyAddr, ok := proxyAddrFN(60 * time.Second)
		if !ok {
			// Instead of finishing here we just log the error and continue, the client
			// we are going to create will surely fail when used and return errors,
			// those errors should be handled by the code that depends on such client.
			log.Errorf("Proxy never came online")
		}
		log.Debugf("Connected to proxy")

		tr.Proxy = func(req *http.Request) (*url.URL, error) {
			return url.Parse("http://" + proxyAddr.(string))
		}
	} else {
		log.Errorf("Using direct http client with no proxyAddr")
	}
	return &http.Client{Transport: tr}, nil
}
