// Package buffers provides shared byte buffers based on bpool
package buffers

import (
	"github.com/oxtoacart/bpool"
)

const (
	maxBuffers = 2500
	bufferSize = 32768
)

var (
	pool = bpool.NewBytePool(maxBuffers, bufferSize)
)

// Get gets a byte buffer from the pool
func Get() []byte {
	return pool.Get()
}

// Put returns a byte buffer to the pool
func Put(b []byte) {
	pool.Put(b)
}
