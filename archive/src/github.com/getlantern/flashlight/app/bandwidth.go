package app

import (
	"github.com/getlantern/bandwidth"

	"github.com/getlantern/flashlight/ui"
)

func serveBandwidth() error {
	helloFn := func(write func(interface{}) error) error {
		log.Debugf("Sending current bandwidth quota to new client")
		return write(bandwidth.GetQuota())
	}

	service, err := ui.Register("bandwidth", helloFn)
	if err == nil {
		go func() {
			for quota := range bandwidth.Updates {
				service.Out <- quota
			}
		}()
	}

	return err
}
