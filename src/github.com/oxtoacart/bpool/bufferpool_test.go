package bpool

import (
	"bytes"
	"testing"
)

func TestBufferPool(t *testing.T) {
	var size int = 4

	bufPool := NewBufferPool(size)

	// Test Get/Put
	b := bufPool.Get()
	bufPool.Put(b)

	// Add some additional buffers beyond the pool size.
	for i := 0; i < size*2; i++ {
		bufPool.Put(bytes.NewBuffer([]byte{}))
	}

	// Close the channel so we can iterate over it.
	close(bufPool.c)

	// Check the size of the pool.
	if len(bufPool.c) != size {
		t.Fatalf("bufferpool size invalid: got %v want %v", len(bufPool.c), size)
	}

}
