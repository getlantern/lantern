package ringfile

import (
	"io"
	"io/ioutil"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
)

var (
	vals = []string{"", "There", "0"}
)

func TestReadWritePointer(t *testing.T) {
	pointer := &filepointer{
		file:   1,
		offset: 26,
		length: 97,
	}

	p := make([]byte, filePointerSize)
	writePointer(p, pointer)
	rt := &filepointer{}
	readPointer(p, rt)
	assert.Equal(t, pointer, rt)
}

func TestUnderCapacity(t *testing.T) {
	doTest(t, len(vals)+1, vals)
}

func TestAtCapacity(t *testing.T) {
	doTest(t, len(vals), vals)
}

func TestOverCapacity(t *testing.T) {
	doTest(t, len(vals)-1, vals[1:])
}

func doTest(t *testing.T, capacity int, expectedReads []string) {
	dir, err := ioutil.TempDir("", "jsonring_test")
	if !assert.NoError(t, err, "Unable to create temp dir") {
		return
	}
	defer os.RemoveAll(dir)
	filename := filepath.Join(dir, "test")

	b, err := New(filename, capacity)
	if !assert.NoError(t, err, "Unable to create buffer") {
		return
	}

	for i := 0; i < len(vals); i++ {
		n, err2 := b.Write([]byte(vals[i]))
		if assert.NoError(t, err2, "Unable to write %v", vals[i]) {
			assert.Equal(t, len(vals[i]), n)
		}
	}

	err = read(t, b, expectedReads)
	if err != nil {
		return
	}

	err = b.Close()
	if !assert.NoError(t, err, "Unable to close buffer") {
		return
	}

	// Reopen the buffer and try reading again
	b, err = New(filename, capacity)
	if !assert.NoError(t, err, "Unable to reopen buffer") {
		return
	}

	err = read(t, b, expectedReads)
	if err != nil {
		return
	}

	err = b.Close()
	if !assert.NoError(t, err, "Unable to close reopened buffer") {
		return
	}

	// Reopen the buffer with an increased capacity and try reading again
	b, err = New(filename, capacity+1)
	if !assert.NoError(t, err, "Unable to reopen increased buffer") {
		return
	}

	err = read(t, b, expectedReads)
	if err != nil {
		return
	}

	err = b.Close()
	if !assert.NoError(t, err, "Unable to close reopened increased buffer") {
		return
	}

	// Reopen the buffer with a decreased capacity and try reading again
	b, err = New(filename, capacity-1)
	if !assert.NoError(t, err, "Unable to reopen decreased buffer") {
		return
	}

	if len(expectedReads) > capacity-1 {
		expectedReads = expectedReads[1:]
	}
	err = read(t, b, expectedReads)
	if err != nil {
		return
	}

	err = b.Close()
	if !assert.NoError(t, err, "Unable to close reopened decreased buffer") {
		return
	}
}

func read(t *testing.T, b Buffer, expectedReads []string) error {
	err := doRead(t, expectedReads, b.AllFromOldest)
	if err != nil {
		return err
	}
	return doRead(t, reverse(expectedReads), b.AllFromNewest)
}

func doRead(t *testing.T, expectedReads []string, readFN func(func(io.Reader) error) error) error {
	var actualReads []string
	err := readFN(func(r io.Reader) error {
		p, err2 := ioutil.ReadAll(r)
		if err2 != nil {
			return err2
		}
		actualReads = append(actualReads, string(p))
		return nil
	})
	if !assert.NoError(t, err, "Unable to read AllFromOldest") {
		return err
	}
	assert.Equal(t, expectedReads, actualReads)
	return nil
}

func reverse(expected []string) []string {
	reversed := make([]string, 0, len(expected))
	for i := len(expected) - 1; i >= 0; i-- {
		reversed = append(reversed, expected[i])
	}
	return reversed
}
