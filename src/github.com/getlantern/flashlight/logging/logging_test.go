package logging

import (
	"bytes"
	"encoding/json"
	"strings"
	"testing"

	"github.com/getlantern/go-loggly"
	"github.com/getlantern/golog"
	"github.com/getlantern/testify/assert"
)

func TestLoggly(t *testing.T) {
	var buf bytes.Buffer
	var result map[string]interface{}
	loggly := loggly.New("token not required")
	loggly.Writer = &buf
	lw := logglyErrorWriter{client: loggly}
	golog.SetOutputs(lw, nil)
	log := golog.LoggerFor("test")

	log.Error("short message")
	if assert.NoError(t, json.Unmarshal(buf.Bytes(), &result), "Unmarshal error") {
		assert.Equal(t, "test", result["locationInfo"])
		assert.Equal(t, "test: short message\n", result["message"])
	}

	buf.Reset()
	longMsg := "really l" + strings.Repeat("o", 100) + "ng message"
	log.Error(longMsg)
	if assert.NoError(t, json.Unmarshal(buf.Bytes(), &result), "Unmarshal error") {
		assert.Equal(t, "test", result["locationInfo"])
		assert.Equal(t, ("test: " + longMsg)[0:100], result["message"], "message should be truncated to 100 characters")
	}
}
