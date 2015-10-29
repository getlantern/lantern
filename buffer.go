package tunio

import (
	"bytes"
	"sync"
)

type Buffer struct {
	bytes.Buffer
	mu sync.RWMutex
}

func (rw *Buffer) Write(p []byte) (int, error) {
	rw.mu.Lock()
	defer rw.mu.Unlock()
	return rw.Buffer.Write(p)
}

func (rw *Buffer) Read(p []byte) (int, error) {
	rw.mu.RLock()
	defer rw.mu.RUnlock()
	return rw.Buffer.Read(p)
}

func (rw *Buffer) Len() int {
	rw.mu.RLock()
	defer rw.mu.RUnlock()
	return rw.Buffer.Len()
}
