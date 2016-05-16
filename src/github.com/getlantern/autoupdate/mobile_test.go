// Tests for mobile_test.go

package autoupdate

import (
	"io/ioutil"
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
)

type TestUpdater struct {
	Updater
}

func (u *TestUpdater) SetProgress(percentage int) {
	log.Debugf("Current progress: %6.02d%%", percentage)
}

func TestCheckUpdateAvailable(t *testing.T) {
	doTestCheckUpdate(t, false, false, "2.2.0")
}

func TestCheckNoUpdateUnavailable(t *testing.T) {
	doTestCheckUpdate(t, true, true, "")
	doTestCheckUpdate(t, true, false, "9.3.3")
}

func doTestCheckUpdate(t *testing.T, urlEmpty, shouldErr bool, version string) string {
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

	return url
}

func TestDoUpdate(t *testing.T) {

	url := doTestCheckUpdate(t, false, false, "2.2.0")
	assert.NotEmpty(t, url)

	out, err := ioutil.TempFile(os.TempDir(), "update")
	assert.Nil(t, err)

	defer os.Remove(out.Name())

	err = doUpdateMobile(false, url, out, new(TestUpdater))
	assert.Nil(t, err)
}
