package server

import (
	"fmt"
	"testing"
)

const (
	testAssetURL = `https://github.com/getlantern/autoupdate/releases/download/2.0.0-beta3/update_darwin_amd64`
)

func TestDownloadAsset(t *testing.T) {
	if _, err := downloadAsset(testAssetURL); err != nil {
		t.Fatal(fmt.Errorf("Failed to download asset: %q", err))
	}
}
