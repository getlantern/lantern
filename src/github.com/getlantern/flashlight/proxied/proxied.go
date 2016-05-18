// Package proxied provides  http.Client implementations that use various
// combinations of chained and direct domain-fronted proxies.
//
// Remember to call SetProxyAddr before obtaining an http.Client.
package proxied

import (
	"crypto/tls"
	"errors"
	"fmt"
	"net"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/getlantern/eventual"
	"github.com/getlantern/fronted"
	"github.com/getlantern/golog"
	"github.com/getlantern/keyman"
)

const (
	forceDF = "FORCE_DOMAINFRONT"
)

var (
	log = golog.LoggerFor("flashlight.proxied")

	proxyAddrMutex sync.RWMutex
	proxyAddr      = eventual.DefaultUnsetGetter()

	// ErrChainedProxyUnavailable indicates that we weren't able to find a chained
	// proxy.
	ErrChainedProxyUnavailable = errors.New("chained proxy unavailable")
)

func success(resp *http.Response) bool {
	return resp.StatusCode > 199 && resp.StatusCode < 400
}

// SetProxyAddr sets the eventual.Getter that's used to determine the proxy's
// address. This MUST be called before attempting to use the proxied package.
func SetProxyAddr(addr eventual.Getter) {
	proxyAddrMutex.Lock()
	proxyAddr = addr
	proxyAddrMutex.Unlock()
}

func getProxyAddr() (string, bool) {
	proxyAddrMutex.RLock()
	addr, ok := proxyAddr(1 * time.Minute)
	proxyAddrMutex.RUnlock()
	if !ok {
		return "", !ok
	}
	return addr.(string), true
}

// ParallelPreferChained creates a new http.RoundTripper that attempts to send
// requests through both chained and direct fronted routes in parallel. Once a
// chained request succeeds, subsequent requests will only go through Chained
// servers unless and until a request fails, in which case we'll start trying
// fronted requests again.
func ParallelPreferChained() http.RoundTripper {
	cf := &chainedAndFronted{
		parallel: true,
	}
	cf.setFetcher(&dualFetcher{cf})
	return cf
}

// ChainedThenFronted creates a new http.RoundTripper that attempts to send
// requests first through a chained server and then falls back to using a
// direct fronted server if the chained route didn't work.
func ChainedThenFronted() http.RoundTripper {
	cf := &chainedAndFronted{
		parallel: false,
	}
	cf.setFetcher(&dualFetcher{cf})
	return cf
}

// ChainedAndFronted fetches HTTP data in parallel using both chained and fronted
// servers.
type chainedAndFronted struct {
	parallel bool
	_fetcher http.RoundTripper
	mu       sync.RWMutex
}

func (cf *chainedAndFronted) getFetcher() http.RoundTripper {
	cf.mu.RLock()
	result := cf._fetcher
	cf.mu.RUnlock()
	return result
}

func (cf *chainedAndFronted) setFetcher(fetcher http.RoundTripper) {
	cf.mu.Lock()
	cf._fetcher = fetcher
	cf.mu.Unlock()
}

// Do will attempt to execute the specified HTTP request using only a chained fetcher
func (cf *chainedAndFronted) RoundTrip(req *http.Request) (*http.Response, error) {
	resp, err := cf.getFetcher().RoundTrip(req)
	if err != nil {
		// If there's an error, switch back to using the dual fetcher.
		cf.setFetcher(&dualFetcher{cf})
	} else if !success(resp) {
		cf.setFetcher(&dualFetcher{cf})
	}
	return resp, err
}

type chainedFetcher struct {
}

// Do will attempt to execute the specified HTTP request using only a chained fetcher
func (cf *chainedFetcher) RoundTrip(req *http.Request) (*http.Response, error) {
	log.Debugf("Using chained fronter")
	rt, err := ChainedNonPersistent("")
	if err != nil {
		log.Errorf("Could not create HTTP client: %v", err)
		return nil, err
	}
	return rt.RoundTrip(req)
}

type dualFetcher struct {
	cf *chainedAndFronted
}

// Do will attempt to execute the specified HTTP request using both
// chained and fronted servers, simply returning the first response to
// arrive. Callers MUST use the Lantern-Fronted-URL HTTP header to
// specify the fronted URL to use.
func (df *dualFetcher) RoundTrip(req *http.Request) (*http.Response, error) {
	directRT, err := ChainedNonPersistent("")
	if err != nil {
		log.Errorf("Could not create http client? %v", err)
		return nil, err
	}
	frontedRT := fronted.NewDirect(5 * time.Minute)
	return df.do(req, directRT.RoundTrip, frontedRT.RoundTrip)
}

// Do will attempt to execute the specified HTTP request using both
// chained and fronted servers. Callers MUST use the Lantern-Fronted-URL HTTP
// header to specify the fronted URL to use.
func (df *dualFetcher) do(req *http.Request, chainedFunc func(*http.Request) (*http.Response, error), ddfFunc func(*http.Request) (*http.Response, error)) (*http.Response, error) {
	log.Debugf("Using dual fronter")
	frontedURL := req.Header.Get("Lantern-Fronted-URL")
	req.Header.Del("Lantern-Fronted-URL")

	if frontedURL == "" {
		return nil, errors.New("Callers MUST specify the fronted URL in the Lantern-Fronted-URL header")
	}

	// Make a copy of the original requeest headers to include in the fronted
	// request. This will ensure that things like the caching headers are
	// included in both requests.
	headersCopy := make(http.Header, len(req.Header))
	for k, vv := range req.Header {
		// Since we're doing domain fronting don't copy the host just in case
		// it ever makes any difference under the covers.
		if strings.EqualFold("Host", k) {
			continue
		}
		vv2 := make([]string, len(vv))
		copy(vv2, vv)
		headersCopy[k] = vv2
	}

	responses := make(chan *http.Response, 2)
	errs := make(chan error, 2)

	request := func(clientFunc func(*http.Request) (*http.Response, error), req *http.Request) error {
		if resp, err := clientFunc(req); err != nil {
			log.Errorf("Could not complete request with: %v, %v", frontedURL, err)
			errs <- err
			return err
		} else {
			if success(resp) {
				log.Debugf("Got successful HTTP call!")
				responses <- resp
				return nil
			} else {
				// If the local proxy can't connect to any upstream proxies, for example,
				// it will return a 502.
				err := fmt.Errorf("Bad response code: %v", resp.StatusCode)
				if resp.Body != nil {
					_ = resp.Body.Close()
				}
				errs <- err
				return err
			}
		}
	}

	doFronted := func() {
		if frontedReq, err := http.NewRequest("GET", frontedURL, nil); err != nil {
			log.Errorf("Could not create request for: %v, %v", frontedURL, err)
			errs <- err
		} else {
			log.Debug("Sending request via DDF")
			frontedReq.Header = headersCopy

			if err := request(ddfFunc, frontedReq); err != nil {
				log.Errorf("Fronted request failed: %v", err)
			} else {
				log.Debug("Fronted request succeeded")
			}
		}
	}

	doChained := func() {
		log.Debug("Sending chained request")
		if err := request(chainedFunc, req); err != nil {
			log.Errorf("Chained request failed %v", err)
		} else {
			log.Debug("Switching to chained fronter for future requests since it succeeded")
			df.cf.setFetcher(&chainedFetcher{})
		}
	}

	getResponse := func() (*http.Response, error) {
		select {
		case resp := <-responses:
			return resp, nil
		case err := <-errs:
			return nil, err
		}
	}

	getResponseParallel := func() (*http.Response, error) {
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

	frontOnly, _ := strconv.ParseBool(os.Getenv(forceDF))
	if frontOnly {
		log.Debug("Forcing domain-fronting")
		doFronted()
		return getResponse()
	}

	if df.cf.parallel {
		go doFronted()
		go doChained()
		return getResponseParallel()
	}

	doChained()
	resp, err := getResponse()
	if err != nil {
		doFronted()
		resp, err = getResponse()
	}
	return resp, err
}

func readResponses(finalResponse chan *http.Response, responses chan *http.Response, finalErr chan error, errs chan error) {
	select {
	case resp := <-responses:
		if success(resp) {
			log.Debug("Got good first response")
			finalResponse <- resp

			// Just ignore the second response, but still process it.
			select {
			case response := <-responses:
				log.Debug("Closing second response body")
				_ = response.Body.Close()
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
		case response := <-responses:
			finalResponse <- response
		case err := <-errs:
			finalErr <- err
		}
	}
}

// ChainedPersistent creates an http.RoundTripper that uses keepalive
// connectionspersists and proxies through chained servers. If rootCA is
// specified, the RoundTripper will validate the server's certificate on TLS
// connections against that RootCA.
func ChainedPersistent(rootCA string) (http.RoundTripper, error) {
	return chained(rootCA, true)
}

// ChainedNonPersistent creates an http.RoundTripper that proxies through
// chained servers and does not use keepalive connections. If rootCA is
// specified, the RoundTripper will validate the server's certificate on TLS
// connections against that RootCA.
func ChainedNonPersistent(rootCA string) (http.RoundTripper, error) {
	return chained(rootCA, false)
}

// chained creates an http.RoundTripper. If rootCA is specified, the
// RoundTripper will validate the server's certificate on TLS connections
// against that RootCA. If persistent is specified, the RoundTripper will use
// keepalive connections across requests.
func chained(rootCA string, persistent bool) (http.RoundTripper, error) {
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

	tr.Proxy = func(req *http.Request) (*url.URL, error) {
		proxyAddr, ok := getProxyAddr()
		if !ok {
			return nil, ErrChainedProxyUnavailable
		}
		return url.Parse("http://" + proxyAddr)
	}

	return tr, nil
}
