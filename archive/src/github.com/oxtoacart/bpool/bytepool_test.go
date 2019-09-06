package bpool

import "testing"

func TestBytePool(t *testing.T) {
	var size int = 4
	var width int = 10

	bufPool := NewBytePool(size, width)

	// Check the width
	if bufPool.Width() != width {
		t.Fatalf("bytepool width invalid: got %v want %v", bufPool.Width(), width)
	}

	// Check that retrieved buffer are of the expected width
	b := bufPool.Get()
	if len(b) != width {
		t.Fatalf("bytepool length invalid: got %v want %v", len(b), width)
	}

	bufPool.Put(b)

	// Fill the pool beyond the capped pool size.
	for i := 0; i < size*2; i++ {
		bufPool.Put(make([]byte, bufPool.w))
	}

	// Close the channel so we can iterate over it.
	close(bufPool.c)

	// Check the size of the pool.
	if len(bufPool.c) != size {
		t.Fatalf("bytepool size invalid: got %v want %v", len(bufPool.c), size)
	}

}
