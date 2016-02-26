package logging

import (
	"bytes"
	"encoding/json"
	"fmt"
	"regexp"
	"strings"
	"testing"

	"github.com/getlantern/go-loggly"
	"github.com/getlantern/golog"
	"github.com/stretchr/testify/assert"
)

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
	lw := logglyErrorWriter{client: loggly}
	golog.SetOutputs(lw, nil)
	log := golog.LoggerFor("test")

	log.Error("")
	if assert.NoError(t, json.Unmarshal(buf.Bytes(), &result), "Unmarshal error") {
		assert.Equal(t, "ERROR test", result["locationInfo"])
		assert.Regexp(t, regexp.MustCompile("logging_test.go:([0-9]+)"), result["message"])
	}

	buf.Reset()
	log.Error("short message")
	if assert.NoError(t, json.Unmarshal(buf.Bytes(), &result), "Unmarshal error") {
		assert.Equal(t, "ERROR test", result["locationInfo"])
		assert.Regexp(t, regexp.MustCompile("logging_test.go:([0-9]+) short message"), result["message"])
	}

	buf.Reset()
	log.Error("message with: reason")
	if assert.NoError(t, json.Unmarshal(buf.Bytes(), &result), "Unmarshal error") {
		assert.Equal(t, "ERROR test", result["locationInfo"])
		assert.Regexp(t, "logging_test.go:([0-9]+) message with: reason", result["message"])
	}

	buf.Reset()
	log.Error("deep reason: message with: reason")
	if assert.NoError(t, json.Unmarshal(buf.Bytes(), &result), "Unmarshal error") {
		assert.Equal(t, "ERROR test", result["locationInfo"])
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
		assert.Equal(t, "ERROR test", result["locationInfo"])
		assert.Equal(t, "an url 127.0.0.1:8787 in message: reason", result["message"], "should not truncate url")
	}

	buf.Reset()
	longPrefix := "message with: really l"
	longMsg := longPrefix + strings.Repeat("o", 100) + "ng reason"
	log.Error(longMsg)
	if assert.NoError(t, json.Unmarshal(buf.Bytes(), &result), "Unmarshal error") {
		assert.Equal(t, "ERROR test", result["locationInfo"])

		assert.Regexp(t, regexp.MustCompile("logging_test.go:([0-9]+) "+longPrefix+"(o+)"), result["message"])
		assert.Equal(t, 100, len(result["message"].(string)))
	}
}
