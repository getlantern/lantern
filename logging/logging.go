package logging

import (
	"bufio"
	"fmt"
	"io"
	"os"

	"github.com/fsnotify/fsnotify"
)

// LogHandler is a function that handles new log messages.
type LogHandler func(string)

// **Watch the log file for changes and send new lines to Dart**
func WatchLogFile(filePath string, logHandler LogHandler) error {
	// Open the file for reading
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

	// Create a buffered reader.
	reader := bufio.NewReader(file)

	// Listen for file changes.
	for {
		select {
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

// readNewLogLines reads new lines from the open file and calls logHandler for each line.
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

	// Read new lines.
	for {
		line, err := reader.ReadString('\n')
		if err != nil {
			break // No more lines to read.
		}
		logHandler(line)
	}

	// Update the offset for the next read.
	newOffset, _ := file.Seek(0, os.SEEK_CUR)
	return newOffset
}

// ReadLastLines reads the last `n` lines of a file and sends them to the logHandler.
func ReadLastLines(filePath string, n int) ([]string, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return nil, fmt.Errorf("error opening log file: %w", err)
	}
	defer file.Close()

	// Read all lines into memory (not ideal for very large files).
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
