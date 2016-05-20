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
	assert.Equal(t, s.GetUserID(), 0)
	assert.Equal(t, s.GetSystemProxy(), true)
	assert.Equal(t, s.IsAutoReport(), true)

	m := make(map[string]interface{})

	m["autoReport"] = false
	m["proxyAll"] = true
	m["autoLaunch"] = false
	m["systemProxy"] = false

	// These should not be booleans, but make sure things don't fail if we send
	// bogus stuff.
	m["userID"] = true
	m["userToken"] = true

	in := make(chan interface{}, 100)
	in <- m
	out := make(chan interface{})
	go s.read(in, out)

	//close(in)
	<-out

	assert.Equal(t, s.GetProxyAll(), true)
	assert.Equal(t, s.GetSystemProxy(), false)
	assert.Equal(t, s.IsAutoReport(), false)
	assert.Equal(t, s.GetUserID(), 0)

	// Test that setting something random doesn't break stuff.
	m["randomjfdklajfla"] = "fadldjfdla"
	in <- m
	<-out
	assert.Equal(t, s.GetProxyAll(), true)

	// Test with an actual user ID.
	var id = 483109
	m["userID"] = id
	in <- m
	<-out
	assert.Equal(t, id, s.GetUserID())
	assert.Equal(t, true, s.GetProxyAll())
}

func TestNotPersistVersion(t *testing.T) {
	path = "./test.yaml"
	version := "version-not-on-disk"
	revisionDate := "1970-1-1"
	buildDate := "1970-1-1"
	set := loadSettings(version, revisionDate, buildDate)
	assert.Equal(t, version, set.Version, "Should be set to version")
}
