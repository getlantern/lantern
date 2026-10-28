package lanterncore

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	rlog "github.com/getlantern/radiance/log"
)

// lantern-core logs through radiance's logger on every platform (common.Init,
// or setupAppLogging on Apple), and that logger redacts helper- tags. This
// guards the dependency: a radiance bump that dropped the redaction would
// put helper tags in issue reports.
func TestAppLogsRedactHelperTags(t *testing.T) {
	// Under go test, radiance's env turns NewLogger into a no-op and disables
	// logging; the OS env takes precedence, so ask for the real file logger.
	t.Setenv("RADIANCE_TESTING", "false")
	t.Setenv("RADIANCE_LOG_LEVEL", "info")
	t.Setenv("RADIANCE_DISABLE_STDOUT_LOG", "true")
	path := filepath.Join(t.TempDir(), AppLogFileName)
	logger := rlog.NewLogger(rlog.Config{LogPath: path, Level: "info", Prod: true, DisablePublisher: true})
	logger.Info("Auto location server:", "server", `{"tag":"helper-0123456789ab"}`)
	data, err := os.ReadFile(path)
	require.NoError(t, err)
	assert.NotContains(t, string(data), "helper-0123456789ab")
	assert.Contains(t, string(data), "helper")
}
