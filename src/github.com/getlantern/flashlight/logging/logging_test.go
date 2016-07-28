package logging

import (
	"bytes"
	"encoding/json"
	"fmt"
	"regexp"
	"strings"
	"testing"
	"time"

	"github.com/getlantern/go-loggly"
	"github.com/getlantern/golog"
	"github.com/stretchr/testify/assert"
)

// Test to make sure user agent registration, listening, etc is all working.
func TestUserAgent(t *testing.T) {
	agent := "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/50.0.2661.86 Safari/537.36"

	// Do an initial register just to test the duplicate agent paths.
	RegisterUserAgent(agent)

	go func() {
		RegisterUserAgent(agent)
	}()

	time.Sleep(200 * time.Millisecond)

	agents := getSessionUserAgents()

	assert.True(t, strings.Contains(agents, "AppleWebKit"), "Expected agent not in "+agents)
}

type BadWriter struct{}
type GoodWriter struct{ counter int }

func (w *BadWriter) Write(p []byte) (int, error) {
	return 0, fmt.Errorf("Fail intentionally")
}

func (w *GoodWriter) Write(p []byte) (int, error) {
	w.counter = len(p)
	return w.counter, nil
}

func TestNonStopWriter(t *testing.T) {
	b, g := BadWriter{}, GoodWriter{}
	ns := NonStopWriter(&b, &g)
	ns.Write([]byte("1234"))
	assert.Equal(t, 4, g.counter, "Should write to all writers even when error encountered")
}

func TestLoggly(t *testing.T) {
	var buf bytes.Buffer
	var result map[string]interface{}
	loggly := loggly.New("token not required")
	loggly.Writer = &buf
	r := logglyErrorReporter{client: loggly}
	golog.RegisterReporter(r.Report)
	log := golog.LoggerFor("test")

	log.Error("")
	log.Debugf("**************** %v", buf.String())
	if assert.NoError(t, json.Unmarshal(buf.Bytes(), &result), "Unmarshal error") {
		assert.Regexp(t, "test: logging_test.go:([0-9]+)", result["locationInfo"])
		assert.Equal(t, "", result["message"])
	}

	buf.Reset()
	log.Error("short message")
	if assert.NoError(t, json.Unmarshal(buf.Bytes(), &result), "Unmarshal error") {
		assert.Regexp(t, "test: logging_test.go:([0-9]+)", result["locationInfo"])
		assert.Equal(t, "short message", result["message"])
	}

	buf.Reset()
	log.Error("message with: reason")
	if assert.NoError(t, json.Unmarshal(buf.Bytes(), &result), "Unmarshal error") {
		assert.Regexp(t, "test: logging_test.go:([0-9]+)", result["locationInfo"])
		assert.Equal(t, "message with: reason", result["message"], "message should be last 2 chunks")
	}

	buf.Reset()
	log.Error("deep reason: message with: reason")
	if assert.NoError(t, json.Unmarshal(buf.Bytes(), &result), "Unmarshal error") {
		assert.Regexp(t, "test: logging_test.go:([0-9]+)", result["locationInfo"])
		assert.Equal(t, "message with: reason", result["message"], "message should be last 2 chunks")
	}

	buf.Reset()
	log.Error("deep reason: an url https://a.com in message: reason")
	if assert.NoError(t, json.Unmarshal(buf.Bytes(), &result), "Unmarshal error") {
		assert.Equal(t, "an url https://a.com in message: reason", result["message"], "should not truncate url")
	}

	buf.Reset()
	log.Error("deep reason: an url 127.0.0.1:8787 in message: reason")
	if assert.NoError(t, json.Unmarshal(buf.Bytes(), &result), "Unmarshal error") {
		assert.Regexp(t, "test: logging_test.go:([0-9]+)", result["locationInfo"])
		assert.Equal(t, "an url 127.0.0.1:8787 in message: reason", result["message"], "should not truncate url")
	}

	buf.Reset()
	longPrefix := "message with: really l"
	longMsg := longPrefix + strings.Repeat("o", 100) + "ng reason"
	log.Error(longMsg)
	if assert.NoError(t, json.Unmarshal(buf.Bytes(), &result), "Unmarshal error") {
		assert.Regexp(t, "test: logging_test.go:([0-9]+)", result["locationInfo"])
		assert.Regexp(t, regexp.MustCompile(longPrefix+"(o+)"), result["message"])
		assert.Equal(t, 100, len(result["message"].(string)))
	}
}
