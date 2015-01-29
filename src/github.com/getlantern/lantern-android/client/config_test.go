package client

import (
	"testing"
)

func TestConfigDownload(t *testing.T) {
	var err error

	if _, err = pullConfigFile(); err != nil {
		t.Fatal(err)
	}
}

func TestConfigParse(t *testing.T) {
	var cfg *config
	var err error

	if cfg, err = getConfig(); err != nil {
		t.Fatal(err)
	}

	if cfg == nil {
		t.Fatal("Expecting non-nil config file.")
	}
}
