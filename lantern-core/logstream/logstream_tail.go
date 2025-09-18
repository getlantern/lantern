// lantern-core/logstream/logstream_tail.go
package logstream

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/fsnotify/fsnotify"
)

type tailProvider struct {
	opts   Options
	cancel context.CancelFunc
	wg     sync.WaitGroup
}

func newTailProvider(opts Options) (provider, error) {
	if opts.LogFile == "" {
		return nil, errors.New("tailProvider requires Options.LogFile")
	}
	return &tailProvider{opts: opts}, nil
}

func (t *tailProvider) Start(ctx context.Context, h Handler) error {
	if h == nil {
		return errors.New("log handler cannot be nil")
	}
	if t.cancel != nil {
		return nil
	}
	ctx, t.cancel = context.WithCancel(ctx)

	logPath, err := filepath.Abs(t.opts.LogFile)
	if err != nil {
		return fmt.Errorf("resolve log path: %w", err)
	}
	logDir := filepath.Dir(logPath)
	logBase := filepath.Base(logPath)

	initial := t.opts.InitialLines
	if initial <= 0 {
		initial = 200
	}
	if _, err := os.Stat(logPath); err == nil {
		if lines, err := readLastLines(logPath, initial); err == nil && len(lines) > 0 {
			h(strings.Join(lines, "\n"))
		}
	}
	w, err := fsnotify.NewWatcher()
	if err != nil {
		return fmt.Errorf("fsnotify.NewWatcher: %w", err)
	}

	// watch both the file (for writes) and the parent dir for create/rotation
	_ = w.Add(logDir)
	_ = w.Add(logPath)

	var file *os.File
	var reader *bufio.Reader
	var offset int64

	openFile := func() error {
		if file != nil {
			file.Close()
			file = nil
		}
		f, err := os.Open(logPath)
		if err != nil {
			return err
		}
		file = f
		reader = bufio.NewReader(file)

		// Reopen to tail and seek to current end
		off, err := file.Seek(0, io.SeekEnd)
		if err != nil {
			return err
		}
		offset = off
		return nil
	}

	_ = openFile()

	readNewLines := func() {
		if file == nil || reader == nil {
			return
		}

		if st, err := file.Stat(); err == nil && st.Size() < offset {
			_, _ = file.Seek(0, io.SeekStart)
			reader.Reset(file)
			offset = 0
		} else {
			_, _ = file.Seek(offset, io.SeekStart)
		}

		var out []string
		for {
			line, err := reader.ReadString('\n')
			if len(line) > 0 {
				out = append(out, strings.TrimRight(line, "\r\n"))
			}
			if err != nil {
				break
			}
		}
		if cur, err := file.Seek(0, io.SeekCurrent); err == nil {
			offset = cur
		}
		if len(out) > 0 {
			h(strings.Join(out, "\n"))
		}
	}

	t.wg.Add(1)
	go func() {
		defer t.wg.Done()
		defer w.Close()
		ticker := time.NewTicker(1500 * time.Millisecond)
		defer ticker.Stop()

		for {
			select {
			case <-ctx.Done():
				return

			case ev, ok := <-w.Events:
				if !ok {
					return
				}
				if ev.Name == logPath && ev.Op&fsnotify.Write == fsnotify.Write {
					readNewLines()
					continue
				}

				if ev.Name == logPath && (ev.Op&(fsnotify.Remove|fsnotify.Rename)) != 0 {
					if file != nil {
						file.Close()
						file, reader = nil, nil
					}
					// Remove watch on the old path
					_ = w.Remove(logPath)
					continue
				}
				if filepath.Dir(ev.Name) == logDir && filepath.Base(ev.Name) == logBase && (ev.Op&fsnotify.Create) == fsnotify.Create {
					_ = w.Add(logPath)
					if err := openFile(); err == nil {
						readNewLines()
					}
					continue
				}

			case err, ok := <-w.Errors:
				if !ok {
					return
				}
				_ = err

			case <-ticker.C:
				readNewLines()
			}
		}
	}()

	return nil
}

func (t *tailProvider) Stop() error {
	if t.cancel != nil {
		t.cancel()
		t.cancel = nil
	}
	t.wg.Wait()
	return nil
}
