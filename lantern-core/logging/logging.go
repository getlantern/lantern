package logging

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"strings"

	"github.com/fsnotify/fsnotify"
	"github.com/getlantern/lantern/lantern-core/dart_api_dl"
)

// LogHandler is a function that handles new log messages.
type LogHandler func(string)

// Configure is used to setup log handling. It returns an error on failure.
func Configure(ctx context.Context, logFile string, logPort int64) error {
	if logPort == 0 {
		return errors.New("missing log port")
	}
	// Check if the log file exists.
	if _, err := os.Stat(logFile); err == nil {
		// Read and send the last 30 lines of the log file.
		lines, err := readLastLines(logFile, 30)
		if err != nil {
			return err
		}
		dart_api_dl.SendToPort(logPort, strings.Join(lines, "\n"))
	}

	go watchLogFile(ctx, logFile, func(message string) {
		dart_api_dl.SendToPort(logPort, message)
	})

	return nil

}

// watchLogFile watches the log file for changes and sends new lines to Dart.
func watchLogFile(ctx context.Context, filePath string, logHandler LogHandler) error {
	file, err := os.Open(filePath)
	if err != nil {
		return fmt.Errorf("error opening log file: %w", err)
	}
	defer file.Close()

	// Move to the end of the file
	offset, err := file.Seek(0, io.SeekEnd)
	if err != nil {
		return fmt.Errorf("error seeking log file: %w", err)
	}

	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		return fmt.Errorf("error creating file watcher: %w", err)
	}
	defer watcher.Close()

	// Add file to watcher
	err = watcher.Add(filePath)
	if err != nil {
		return fmt.Errorf("error watching file: %w", err)
	}

	reader := bufio.NewReader(file)

	// Listen for file changes.
	for {
		select {
		// Handle context cancellation
		case <-ctx.Done():
			return ctx.Err()
		case event, ok := <-watcher.Events:
			if !ok {
				return nil
			}
			// If the file is modified, read new lines.
			if event.Op&fsnotify.Write == fsnotify.Write {
				offset = readNewLogLines(file, reader, offset, logHandler)
			}
		case err, ok := <-watcher.Errors:
			if !ok {
				return nil
			}
			fmt.Println("Error watching file:", err)
		}
	}
}

// readNewLogLines reads new lines from the open file and calls logHandler on each line.
func readNewLogLines(file *os.File, reader *bufio.Reader, lastOffset int64, logHandler LogHandler) int64 {
	// Get the current file size.
	fileInfo, err := file.Stat()
	if err != nil {
		fmt.Println("Error getting file info:", err)
		return lastOffset
	}

	// If the file was truncated, reset the offset.
	if fileInfo.Size() < lastOffset {
		fmt.Println("Log file was truncated, resetting offset to 0")
		file.Seek(0, os.SEEK_SET)
		lastOffset = 0
	}

	// Move to the last known offset.
	file.Seek(lastOffset, os.SEEK_SET)

	for {
		line, err := reader.ReadString('\n')
		if err != nil {
			break
		}
		logHandler(line)
	}

	// Update the offset for the next read.
	newOffset, _ := file.Seek(0, os.SEEK_CUR)
	return newOffset
}

// readLastLines reads the last `n` lines of a file and sends them to the logHandler.
func readLastLines(filePath string, n int) ([]string, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return nil, fmt.Errorf("error opening log file: %w", err)
	}
	defer file.Close()

	lines := []string{}
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		lines = append(lines, scanner.Text())
	}

	// Handle scanning errors.
	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("error reading log file: %w", err)
	}

	// Determine how many lines to return.
	start := 0
	if len(lines) > n {
		start = len(lines) - n
	}

	return lines[start:], nil
}
