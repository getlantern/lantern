package tarfs

import (
	"bytes"
	"encoding/hex"
	"io"
	"io/ioutil"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestIgnoreEmpty(t *testing.T) {
	tarString := bytes.NewBuffer(nil)
	err := EncodeToTarString("resources", tarString)
	if err != nil {
		t.Fatalf("Unable to encode to tar string: %v", err)
	}

	fs, err := New(tarStringToBytes(t, tarString), "localresources")
	if err != nil {
		t.Fatalf("Unable to open filesystem: %v", err)
	}

	// Test to make sure we get the file if we're not ignoring empty.
	// Note empty on disk actually has a single space to allow us to
	// check it into git, but the method ignores whitespace.
	a, err := fs.Get("empty.txt")
	if assert.NoError(t, err, "empty.txt should have loaded") {
		assert.Equal(t, " \n", string(a), "A should have matched expected")
	}

	// We artificially change the entry for empty byte in the file system
	// to make sure we get the file system and not the local version.
	emptyBytes := []byte("empty")
	fs.files["empty.txt"] = emptyBytes

	a, err = fs.GetIgnoreLocalEmpty("empty.txt")
	if assert.NoError(t, err, "empty.txt should have loaded") {
		assert.Equal(t, string(emptyBytes), string(a), "A should have matched expected")
	}
}

func TestRoundTrip(t *testing.T) {
	expectedA, err := ioutil.ReadFile("resources/a.txt")
	if err != nil {
		t.Fatalf("Unable to load expectedA: %v", err)
	}

	expectedB, err := ioutil.ReadFile("localresources/sub/b.txt")
	if err != nil {
		t.Fatalf("Unable to load expectedB: %v", err)
	}

	expectedC, err := ioutil.ReadFile("resources/sub/c.txt")
	if err != nil {
		t.Fatalf("Unable to load expectedC: %v", err)
	}

	tarString := bytes.NewBuffer(nil)
	err = EncodeToTarString("resources", tarString)
	if err != nil {
		t.Fatalf("Unable to encode to tar string: %v", err)
	}

	fs, err := New(tarStringToBytes(t, tarString), "localresources")
	if err != nil {
		t.Fatalf("Unable to open filesystem: %v", err)
	}

	a, err := fs.Get("a.txt")
	if assert.NoError(t, err, "a.txt should have loaded") {
		assert.Equal(t, string(expectedA), string(a), "A should have matched expected")
	}

	b, err := fs.Get("sub/b.txt")
	if assert.NoError(t, err, "b.txt should have loaded") {
		assert.Equal(t, string(expectedB), string(b), "B should have matched expected")
	}

	f, err := fs.Open("/nonexistentdirectory/")
	if assert.NoError(t, err, "Opening nonexistent directory should work") {
		fi, err := f.Stat()
		if assert.NoError(t, err, "Should be able to stat directory") {
			assert.True(t, fi.IsDir(), "Nonexistent directory should be a directory")
		}
	}

	f, err = fs.Open("/nonexistentfile")
	assert.Error(t, err, "Opening nonexistent file should fail")

	f, err = fs.Open("/sub//c.txt")
	if assert.NoError(t, err, "Opening existing file with double slash should work") {
		fi, err := f.Stat()
		if assert.NoError(t, err, "Should be able to stat file") {
			if assert.False(t, fi.IsDir(), "File should not be a directory") {
				if assert.EqualValues(t, len(expectedC), fi.Size(), "File info should report correct size") {
					a := bytes.NewBuffer(nil)
					_, err := io.Copy(a, f)
					if assert.NoError(t, err, "Should be able to read from file") {
						assert.Equal(t, expectedC, a.Bytes(), "Should have read correct data")
					}
				}
			}
		}
	}

	sub := fs.SubDir("sub")
	b, err = sub.Get("b.txt")
	if assert.NoError(t, err, "b.txt should have loaded from sub") {
		assert.Equal(t, string(expectedB), string(b), "B should have matched expected")
	}

	c, err := sub.Get("c.txt")
	if assert.NoError(t, err, "c.txt should have loaded from sub") {
		assert.Equal(t, string(expectedC), string(c), "C should have matched expected")
	}
}

// tarStringToBytes converts a string like \x69\x6e\x64\x65\x78\x2e\x68\x74 into
// a byte array.
func tarStringToBytes(t *testing.T, bbuf *bytes.Buffer) []byte {
	tarString := string(bbuf.Bytes())
	buf := make([]byte, 0, len(tarString)/4)
	for i := 0; i < len(tarString); i += 4 {
		s := tarString[i+2 : i+4]
		b, err := hex.DecodeString(s)
		if err != nil {
			t.Fatalf("Unable to decode %v: %v", err)
		}
		buf = append(buf, b...)
	}
	return buf
}
