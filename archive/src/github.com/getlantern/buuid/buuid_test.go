package buuid

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestRandom(t *testing.T) {
	id1 := Random()
	id2 := Random()
	assert.NotEqual(t, id1.ToBytes(), id2.ToBytes())
}

func TestReadWriteOK(t *testing.T) {
	id1 := Random()
	b := make([]byte, EncodedLength)
	err := id1.Write(b)
	assert.NoError(t, err, "Unable to write")
	id2, err := Read(b)
	assert.NoError(t, err, "Unable to read")
	assert.Equal(t, id1.ToBytes(), id2.ToBytes(), "Read didn't match written")
}

func TestWriteFailure(t *testing.T) {
	id1 := Random()
	b := make([]byte, EncodedLength-1)
	err := id1.Write(b)
	assert.Error(t, err)
}

func TestReadFailure(t *testing.T) {
	id1 := Random()
	b := make([]byte, EncodedLength)
	err := id1.Write(b)
	assert.NoError(t, err, "Unable to write")
	_, err = Read(b[:EncodedLength-1])
	assert.Error(t, err, "Read should have failed")
}

func TestStringOK(t *testing.T) {
	id1 := Random()
	id1String := id1.String()
	id2, err := FromString(id1String)
	assert.NoError(t, err, "Unable to read from string")
	assert.Equal(t, id1.ToBytes(), id2.ToBytes(), "Read didn't match written")
}

func TestStringFailure(t *testing.T) {
	id1 := Random()
	id1String := id1.String()
	_, err := FromString(id1String[1:])
	assert.Error(t, err, "Reading from string should have failed")
}
