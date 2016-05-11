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

	b, err := New(filepath.Join(dir, "file1"), capacity)
	if !assert.NoError(t, err, "Unable to create buffer") {
		return
	}

	for i := 0; i < len(vals); i++ {
		n, err2 := b.Write([]byte(vals[i]))
		if assert.NoError(t, err2, "Unable to write %v", vals[i]) {
			assert.Equal(t, len(vals[i]), n)
		}
	}

	var actualReads []string
	err = b.AllFromOldest(func(r io.Reader) error {
		p, err2 := ioutil.ReadAll(r)
		if err2 != nil {
			return err2
		}
		actualReads = append(actualReads, string(p))
		return nil
	})
	if assert.NoError(t, err, "Unable to read AllFromOldest") {
		assert.Equal(t, expectedReads, actualReads)
	}
}
