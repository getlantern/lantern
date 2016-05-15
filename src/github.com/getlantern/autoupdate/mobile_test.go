// Tests for mobile_test.go

package autoupdate

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestUpdateAvailable(t *testing.T) {
	doTestUpdate(t, false, false, "2.2.0")
}

func TestNoUpdateUnavailable(t *testing.T) {
	doTestUpdate(t, true, true, "")
	doTestUpdate(t, true, false, "9.3.3")
}

func doTestUpdate(t *testing.T, urlEmpty bool, shouldErr bool, version string) {
	url, err := CheckMobileUpdate(false, version)

	if shouldErr {
		assert.NotNil(t, err)
	} else {
		assert.Nil(t, err)
	}

	if urlEmpty {
		assert.Empty(t, url)
	} else {
		assert.NotEmpty(t, url)
	}
}
