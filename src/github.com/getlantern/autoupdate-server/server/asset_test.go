package server

import (
	"fmt"
	"testing"
)

const (
	testAssetURL = `https://github.com/getlantern/autoupdate-server/releases/download/0.4.0/autoupdate-binary-darwin-amd64.v4`
)

func TestDownloadAsset(t *testing.T) {
	if _, err := downloadAsset(testAssetURL); err != nil {
		t.Fatal(fmt.Errorf("Failed to download asset: %q", err))
	}
}
