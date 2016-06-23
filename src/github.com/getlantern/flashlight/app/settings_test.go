package app

import (
	"encoding/base64"
	"encoding/json"
	"io/ioutil"
	"os"
	"strings"
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

	var uid int64
	s := loadSettingsFrom("1", "1/1/1", "1/1/1", tmpfile.Name())
	assert.Equal(t, s.GetProxyAll(), false)
	assert.Equal(t, s.GetUserID(), uid)
	assert.Equal(t, s.GetSystemProxy(), true)
	assert.Equal(t, s.IsAutoReport(), true)
	assert.Equal(t, s.GetLanguage(), "")

	// Start with raw JSON so we actually decode the map from scratch, as that
	// will then simulate real world use where we rely on Go to generate the
	// actual types of the JSON values. For example, all numbers will be
	// decoded as float64.
	var data = `{
		"autoReport": false,
		"proxyAll": true,
		"autoLaunch": false,
		"systemProxy": false,
		"deviceID": "8208fja09493",
		"userID": 890238588,
		"language": "en-US"
	}`

	var m map[string]interface{}
	d := json.NewDecoder(strings.NewReader(data))

	// Make sure to use json.Number here to avoid issues with 64 bit integers.
	d.UseNumber()
	err = d.Decode(&m)

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
	assert.Equal(t, s.GetLanguage(), "en-US")

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
	var id json.Number = "483109"
	var expected int64 = 483109
	m["userID"] = id
	in <- m
	<-out
	assert.Equal(t, expected, s.GetUserID())
	assert.Equal(t, true, s.GetProxyAll())
}

func TestCheckNum(t *testing.T) {
	snTest := SettingName("test")
	set := newSettings("/dev/null")
	var val json.Number = "4809"
	var expected int64 = 4809
	set.checkNum(snTest, val)
	assert.Equal(t, expected, set.m[snTest])

	set.checkString(snTest, val)

	// The above should not have worked since it's not a string -- should
	// still be an int64
	assert.Equal(t, expected, set.m[snTest])

	set.checkBool(snTest, val)

	// The above should not have worked since it's not a bool -- should
	// still be an int64
	assert.Equal(t, expected, set.m[snTest])
}

func TestPersistAndLoad(t *testing.T) {
	version := "version-not-on-disk"
	revisionDate := "1970-1-1"
	buildDate := "1970-1-1"
	yamlFile := "./test.yaml"
	set := loadSettingsFrom(version, revisionDate, buildDate, yamlFile)
	assert.Equal(t, version, set.m["version"], "Should be set to version")
	assert.Equal(t, revisionDate, set.m["revisionDate"], "Should be set to revisionDate")
	assert.Equal(t, buildDate, set.m["buildDate"], "Should be set to buildDate")
	assert.Equal(t, "en", set.GetLanguage(), "Should load language from file")
	assert.Equal(t, int64(1), set.GetUserID(), "Should load user id from file")

	set.SetLanguage("leet")
	set.SetUserID(1234)
	set2 := loadSettingsFrom(version, revisionDate, buildDate, yamlFile)
	assert.Equal(t, "leet", set2.GetLanguage(), "Should save language to file and reload")
	assert.Equal(t, int64(1234), set2.GetUserID(), "Should save user id to file and reload")
	set2.SetLanguage("en")
	set2.SetUserID(1)
}

func TestLoadLowerCased(t *testing.T) {
	set := loadSettingsFrom("", "", "", "./lowercased.yaml")
	assert.Equal(t, int64(1234), set.GetUserID(), "Should load user id from lower cased yaml")
	assert.Equal(t, "abcd", set.GetToken(), "Should load user token from lower cased yaml")
}

func TestOnChange(t *testing.T) {
	set := newSettings("/dev/null")
	in := make(chan interface{})
	out := make(chan interface{})
	var changed string
	set.OnChange(SNLanguage, func(v interface{}) {
		changed = v.(string)
	})
	go func() {
		set.read(in, out)
	}()
	in <- map[string]interface{}{"language": "en"}
	_ = <-out
	assert.Equal(t, "en", changed, "should call OnChange callback")
}
