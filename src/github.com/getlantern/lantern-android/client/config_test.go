package client

import (
	"net/http"
	"testing"

	"github.com/getlantern/flashlight/globals"
	"github.com/getlantern/flashlight/withclient"
)

func TestConfigDownload(t *testing.T) {

	// Resetting Etag.
	lastCloudConfigETag = ""

	cfg := defaultConfig()
	if err := globals.SetTrustedCAs(cfg.getTrustedCerts()); err != nil {
		t.Fatal(err)
	}
	mch := withclient.NewMakerChan()
	mch.UpdateClientDirectFronter(cfg.Client)
	mch.MakeWithClient()(func(c *http.Client) {

		var err error
		var buf []byte

		// Pulling first time.
		if buf, err = pullConfigFile(c); err != nil {
			t.Fatal(err)
		}
		// Test that we actually got a valid config.
		if err = cfg.updateFrom(buf); err != nil {
			t.Fatal(err)
		}
		// Pulling a second time should trigger an error.
		if _, err = pullConfigFile(c); err != nil {
			if err != errConfigurationUnchanged {
				t.Fatal(err)
			}
		}
	})
}
