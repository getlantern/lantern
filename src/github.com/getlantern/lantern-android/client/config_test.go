package client

import (
	"testing"
)

func TestConfigDownload(t *testing.T) {
	var err error

	// Resetting Etag.
	lastCloudConfigETag = ""

	client := directHttpClientFromConfig(defaultConfig())
	if client == nil {
		t.Fatal("Expected non-nil direct-fronted client")
	}

	// Pulling first time.
	if _, err = pullConfigFile(client); err != nil {
		t.Fatal(err)
	}

	// Pulling a second time should trigger an error.
	if _, err = pullConfigFile(client); err != nil {
		if err != errConfigurationUnchanged {
			t.Fatal(err)
		}
	}
}

func TestConfigParse(t *testing.T) {
	var cfg *config
	var err error

	// Resetting Etag.
	lastCloudConfigETag = ""

	if cfg, err = getConfig(); err != nil {
		t.Fatal(err)
	}

	if cfg == nil {
		t.Fatal("Expecting non-nil config file.")
	}
}
