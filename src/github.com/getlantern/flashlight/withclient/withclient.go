package withclient

import (
	"net/http"
	"sync"

	"github.com/getlantern/golog"

	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/flashlight/config"
	"github.com/getlantern/flashlight/util"
)

var (
	log = golog.LoggerFor("withclient")
)

// The following are mostly meant to
//   (i)   keep track of directly fronted Dialers, closing them when they
//         get superseded by a config update.
//   (ii)  avoid creating more Dialers than needed (one per config update).
//   (iii) make these dialers available to the config custom poll, without
//         introducing globals.
//   (iv)  present a uniform interface in the server side, currently for
//         the benefit of the config custom poll.
//
// Thus, most of the functionality is meant for the client side, and we
// use mostly placeholders in the server side.  Because of this and for
// agility of exposition, the comments below refer to the client side.

type clientRef struct {
	// A particular reference to the directly fronted http.Client (aka fronter).
	client *http.Client
	// Placeholder for any cleanup required when this reference is no longer
	// needed.  We keep track of currently used references with a WaitGroup,
	// and we use this function to signal we're Done() with this one.
	release func()
}

// Basically, clientRefMaker wraps a fronted.Dialer, adding a thunk (ie.,
// `close`) that will wait for all `clientRef`s to be released before
// calling dialer.Close().
type clientRefMaker struct {
	// Generates structures like the one above.
	newClientRef func() clientRef
	// Placeholder for any cleanup required when this clientRefMaker (and
	// hence the Dialer it wraps) is no longer current because we have got
	// a new one (by a config update).
	close func()
}

// To synchronize access to the current clientRefMaker.  Used as a promise that
// can be updated.
type MakerChan chan clientRefMaker

func NewMakerChan() MakerChan {
	return make(chan clientRefMaker, 1)
}

// Returns the old one, if any.
func (ch MakerChan) updateMaker(c clientRefMaker) (ret clientRefMaker) {
	select {
	case ret = <-ch:
	default:
	}
	ch <- c
	return ret
}

func (ch MakerChan) getMaker() clientRefMaker {
	ret := <-ch
	ch <- ret
	return ret
}

// Creates a "context" function that takes care of all the bookkeeping involved
// in making sure Dialers are kept only for as long as needed and closed as soon as
// nobody is using them-- but no sooner.
//
// The function returned by this call is meant to be used like this:
//
// withClient(func(c *http.Client) {
//    ... use `c` here ...
// })
//
// No explicit cleanup is required in the body where `c` is used, but `c` should
// never be used after the body has returned.  So don't assign `c` to variables
// or data structures outside the body, don't use it inside a goroutine, etc.
func (ch MakerChan) MakeWithClient() func(func(*http.Client)) {
	return func(f func(*http.Client)) {
		cr := ch.getMaker().newClientRef()
		defer cr.release()
		f(cr.client)
	}
}

func (ch MakerChan) UpdateClientDirectFronter(cfg *client.ClientConfig) {
	log.Debug("Updating client direct fronter")
	hqfd := cfg.HighestQOSFrontedDialer()
	if hqfd == nil {
		log.Errorf("No fronted dialer available")
		return
	}
	// An *http.Client that uses the highest QOS dialer.
	hqfdClient := hqfd.NewDirectDomainFronter()
	wg := sync.WaitGroup{}
	old := ch.updateMaker(
		clientRefMaker{
			newClientRef: func() clientRef {
				wg.Add(1)
				return clientRef{
					client:  hqfdClient,
					release: wg.Done,
				}
			},
			close: func() {
				wg.Wait()
				hqfd.Close()
			}})
	if old.close != nil {
		log.Debug("Closing old dialer")
		go old.close()
	}
}

func (ch MakerChan) UpdateServerConfigClient(cfg *config.Config) {
	client, err := util.HTTPClient(cfg.CloudConfigCA, "")
	if err != nil {
		log.Errorf("Couldn't create http.Client for fetching the config")
		return
	}
	doNothing := func() {}
	ret := clientRef{
		client:  client,
		release: doNothing,
	}
	ch.updateMaker(
		clientRefMaker{
			newClientRef: func() clientRef { return ret },
			close:        doNothing,
		})
}
