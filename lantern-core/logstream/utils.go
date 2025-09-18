package logstream

import (
	"bufio"
	"bytes"
	"io"
	"os"
)

func readLastLines(filePath string, n int) ([]string, error) {
	if n <= 0 {
		return nil, nil
	}
	f, err := os.Open(filePath)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	const chunk = 64 * 1024
	fi, err := f.Stat()
	if err != nil {
		return nil, err
	}
	size := fi.Size()
	var (
		start int64
		buf   []byte
	)

	//  // grow the window until we have enough newlines
	for window := int64(chunk); ; window += int64(chunk) {
		if window > size {
			window = size
		}
		start = size - window
		if _, err := f.Seek(start, io.SeekStart); err != nil {
			return nil, err
		}
		b := make([]byte, window)
		if _, err := io.ReadFull(f, b); err != nil {
			return nil, err
		}
		buf = b

		if bytes.Count(buf, []byte{'\n'}) >= n || start == 0 {
			break
		}
		if start == 0 {
			break
		}
	}

	// split to lines n and take the tail
	s := bufio.NewScanner(bytes.NewReader(buf))
	s.Buffer(make([]byte, 0, 64*1024), 1<<20)
	lines := make([]string, 0, n)
	for s.Scan() {
		lines = append(lines, s.Text())
	}
	if len(lines) > n {
		lines = lines[len(lines)-n:]
	}
	return lines, nil
}
