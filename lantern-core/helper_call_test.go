package lanterncore

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/getlantern/lantern/lantern-core/helper"
)

func TestHelperCallAnswersJSONAndNeverARawError(t *testing.T) {
	relay := func(context.Context, string, []byte) (int, []byte, string, error) {
		return 200, []byte(`{"pairings":[]}`), "", nil
	}
	lc := &LanternCore{ctx: context.Background(), helpers: helper.NewEngine(t.TempDir(), relay, nil)}

	assert.JSONEq(t, `{"error":"locked"}`, lc.HelperCall("view", "{}"))
	key := base64.StdEncoding.EncodeToString([]byte(strings.Repeat("k", 32)))
	var v map[string]any
	require.NoError(t, json.Unmarshal([]byte(lc.HelperCall("unlock", `{"key":"`+key+`"}`)), &v))
	assert.Equal(t, true, v["unlocked"])
	require.NoError(t, json.Unmarshal([]byte(lc.HelperCall("refresh", "")), &v))
	assert.Equal(t, true, v["unlocked"])
	assert.JSONEq(t, `{"error":"internal"}`, lc.HelperCall("no-such-op", "{}"))
}
