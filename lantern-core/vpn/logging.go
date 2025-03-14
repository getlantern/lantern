package vpn

import (
	"context"
	"os"
	"strings"

	"github.com/getlantern/lantern-outline/lantern-core/dart_api_dl"
	"github.com/getlantern/lantern-outline/lantern-core/logging"
)

func configureLogging(ctx context.Context, logFile string, logPort uint32) error {

	// Check if the log file exists.
	if _, err := os.Stat(logFile); err == nil {
		// Read and send the last 30 lines of the log file.
		lines, err := logging.ReadLastLines(logFile, 30)
		if err != nil {
			return err
		}
		dart_api_dl.SendToPort(logPort, strings.Join(lines, "\n"))
	}

	go logging.WatchLogFile(ctx, logFile, func(message string) {
		dart_api_dl.SendToPort(logPort, message)
	})

	return nil
}
