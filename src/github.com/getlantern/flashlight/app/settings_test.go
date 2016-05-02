package app

import (
	"io/ioutil"
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestRead(t *testing.T) {
	// Avoid polluting real settings.
	tmpfile, err := ioutil.TempFile("", "test")
	if err != nil {
		t.Errorf("Could not create temp file %v", err)
	}

	defer os.Remove(tmpfile.Name()) // clean up

	s := loadSettingsFrom("1", "1/1/1", "1/1/1", tmpfile.Name())
	assert.Equal(t, s.GetProxyAll(), false)
	assert.Equal(t, s.GetUserID(), "")
	assert.Equal(t, s.GetSystemProxy(), true)
	assert.Equal(t, s.IsAutoReport(), true)

	m := make(map[string]interface{})

	m["autoReport"] = false
	m["proxyAll"] = true
	m["autoLaunch"] = false
	m["systemProxy"] = false

	// These should be strings, but make sure things don't fail if we send
	// bogus stuff.
	m["userID"] = true
	m["token"] = true

	in := make(chan interface{}, 100)
	in <- m
	out := make(chan interface{})
	go s.read(in, out)

	//close(in)
	<-out

	assert.Equal(t, s.GetProxyAll(), true)
	assert.Equal(t, s.GetSystemProxy(), false)
	assert.Equal(t, s.IsAutoReport(), false)
	assert.Equal(t, s.GetUserID(), "")

	// Test that setting something random doesn't break stuff.
	m["randomjfdklajfla"] = "fadldjfdla"
	in <- m
	<-out
	assert.Equal(t, s.GetProxyAll(), true)

	// Test with an actual user ID.
	id := "qrueiquriqepuriop"
	m["userID"] = id
	in <- m
	<-out
	assert.Equal(t, s.GetUserID(), id)
	assert.Equal(t, s.GetProxyAll(), true)
}

func TestNotPersistVersion(t *testing.T) {
	path = "./test.yaml"
	version := "version-not-on-disk"
	revisionDate := "1970-1-1"
	buildDate := "1970-1-1"
	loadSettings(version, revisionDate, buildDate)
	assert.Equal(t, settings.Version, version, "Should be set to version")
}
