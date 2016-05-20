package app

import (
	"encoding/base64"
	"encoding/json"
	"io/ioutil"
	"os"
	"testing"

	"code.google.com/p/go-uuid/uuid"

	"github.com/stretchr/testify/assert"
)

func TestRead(t *testing.T) {
	// Avoid polluting real settings.
	tmpfile, err := ioutil.TempFile("", "test")
	if err != nil {
		t.Errorf("Could not create temp file %v", err)
	}

	defer os.Remove(tmpfile.Name()) // clean up

	var uid float64
	s := loadSettingsFrom("1", "1/1/1", "1/1/1", tmpfile.Name())
	assert.Equal(t, s.GetProxyAll(), false)
	assert.Equal(t, s.GetUserID(), uid)
	assert.Equal(t, s.GetSystemProxy(), true)
	assert.Equal(t, s.IsAutoReport(), true)

	// Start with raw JSON so we actually decode the map from scratch, as that
	// will then simulate real world use where we rely on Go to generate the
	// actual types of the JSON values. For example, all numbers will be
	// decoded as float64.
	var data = []byte(`{
		"autoReport": false,
		"proxyAll": true,
		"autoLaunch": false,
		"systemProxy": false,
		"deviceID": "8208fja09493",
		"userID": 890238588
	}`)

	var m map[string]interface{}
	json.Unmarshal(data, &m)

	in := make(chan interface{}, 100)
	in <- m
	out := make(chan interface{})
	go s.read(in, out)

	<-out

	uid = 890238588
	assert.Equal(t, s.GetProxyAll(), true)
	assert.Equal(t, s.GetSystemProxy(), false)
	assert.Equal(t, s.IsAutoReport(), false)
	assert.Equal(t, s.GetUserID(), uid)
	assert.Equal(t, s.GetDeviceID(), base64.StdEncoding.EncodeToString(uuid.NodeID()))

	// Test that setting something random doesn't break stuff.
	m["randomjfdklajfla"] = "fadldjfdla"

	// Test tokens while we're at it.
	token := "token"
	m["userToken"] = token
	in <- m
	<-out
	assert.Equal(t, s.GetProxyAll(), true)
	assert.Equal(t, s.GetToken(), token)

	// Test with an actual user ID.
	var id float64 = 483109
	m["userID"] = id
	in <- m
	<-out
	assert.Equal(t, id, s.GetUserID())
	assert.Equal(t, true, s.GetProxyAll())
}

func TestCheckNum(t *testing.T) {
	set := &Settings{}
	m := make(map[string]interface{})

	var val float64 = 4809
	m["test"] = val
	set.checkNum(m, "test", func(val float64) {
		assert.Equal(t, val, val)
	})

	set.checkString(m, "test", func(val string) {
		assert.Fail(t, "Should not have been called")
	})

	set.checkBool(m, "test", func(val bool) {
		assert.Fail(t, "Should not have been called")
	})
}

func TestNotPersistVersion(t *testing.T) {
	path = "./test.yaml"
	version := "version-not-on-disk"
	revisionDate := "1970-1-1"
	buildDate := "1970-1-1"
	set := loadSettings(version, revisionDate, buildDate)
	assert.Equal(t, version, set.Version, "Should be set to version")
}
