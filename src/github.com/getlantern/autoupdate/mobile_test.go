// Tests for mobile_test.go

package autoupdate

import (
	"io/ioutil"
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
)

var (
	updateServer = "https://update-stage.getlantern.org/update"
)

type TestUpdater struct {
	Updater
}

func (u *TestUpdater) PublishProgress(percentage int) {
	log.Debugf("Current progress: %6.02d%%", percentage)
}

func TestCheckUpdateAvailable(t *testing.T) {
	// test with an older version number
	doTestCheckUpdate(t, false, false, "2.2.0")
}

func TestCheckNoUpdateUnavailable(t *testing.T) {
	// test with a blank version number
	doTestCheckUpdate(t, true, true, "")
	// test with a way newer version
	doTestCheckUpdate(t, true, false, "9.3.3")
}

// urlEmpty and shouldErr are booleans that indicate whether or not
// CheckMobileUpdate should return a blank url or non-nil error
func doTestCheckUpdate(t *testing.T, urlEmpty, shouldErr bool, version string) string {
	url, err := CheckMobileUpdate(false, updateServer, version)

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

	return url
}

func TestDoUpdate(t *testing.T) {

	url := doTestCheckUpdate(t, false, false, "2.2.0")
	assert.NotEmpty(t, url)

	// create a temporary file to write the update to
	out, err := ioutil.TempFile(os.TempDir(), "update")
	assert.Nil(t, err)

	defer os.Remove(out.Name())

	testUpdater := new(TestUpdater)

	// check for an invalid apk path destination
	err = UpdateMobile(false, url, "", testUpdater)
	assert.NotNil(t, err)

	// check for a missing url
	err = doUpdateMobile(false, "", out, testUpdater)
	assert.NotNil(t, err)

	// successful update
	err = doUpdateMobile(false, url, out, testUpdater)
	assert.Nil(t, err)

}
