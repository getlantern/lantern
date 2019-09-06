package bpool

import (
	"bytes"
	"testing"
)

// TestSizedBufferPool checks that over-sized buffers are released and that new
// buffers are created in their place.
func TestSizedBufferPool(t *testing.T) {

	var size int = 4
	var capacity int = 1024

	bufPool := NewSizedBufferPool(size, capacity)

	b := bufPool.Get()

	// Check the cap before we use the buffer.
	if cap(b.Bytes()) != capacity {
		t.Fatalf("buffer capacity incorrect: got %v want %v", cap(b.Bytes()),
			capacity)
	}

	// Grow the buffer beyond our capacity and return it to the pool
	b.Grow(capacity * 3)
	bufPool.Put(b)

	// Add some additional buffers to fill up the pool.
	for i := 0; i < size; i++ {
		bufPool.Put(bytes.NewBuffer(make([]byte, 0, bufPool.a*2)))
	}

	// Check that oversized buffers are being replaced.
	if len(bufPool.c) < size {
		t.Fatalf("buffer pool too small: got %v want %v", len(bufPool.c), size)
	}

	// Close the channel so we can iterate over it.
	close(bufPool.c)

	// Check that there are buffers of the correct capacity in the pool.
	for buffer := range bufPool.c {
		if cap(buffer.Bytes()) != bufPool.a {
			t.Fatalf("returned buffers wrong capacity: got %v want %v",
				cap(buffer.Bytes()), capacity)
		}
	}

}
