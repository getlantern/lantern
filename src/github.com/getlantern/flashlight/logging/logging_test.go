package logging

import (
	"bytes"
	"encoding/json"
	"regexp"
	"strings"
	"testing"

	"github.com/getlantern/go-loggly"
	"github.com/getlantern/golog"
	"github.com/stretchr/testify/assert"
)

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
