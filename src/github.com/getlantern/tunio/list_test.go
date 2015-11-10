package tunio

import (
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestConnList(t *testing.T) {
	var err error
	assert := assert.New(t)

	cl := NewConnList(5)

	// []
	assert.Equal(-1, cl.Head())
	assert.Equal(-1, cl.Tail())
	assert.Equal(0, cl.Size())

	// [16]
	err = cl.Add(16, nil)
	assert.NoError(err)

	assert.Equal(16, cl.Head())
	assert.Equal(16, cl.Tail())
	assert.Equal(1, cl.Size())

	// [16]
	err = cl.Add(16, nil)
	assert.NoError(err)

	assert.Equal(16, cl.Head())
	assert.Equal(16, cl.Tail())
	assert.Equal(1, cl.Size())

	// [11,16]
	err = cl.Add(11, nil)
	assert.NoError(err)

	assert.Equal(11, cl.Head())
	assert.Equal(16, cl.Tail())
	assert.Equal(2, cl.Size())

	// [24,11,16]
	err = cl.Add(24, nil)
	assert.NoError(err)

	assert.Equal(24, cl.Head())
	assert.Equal(16, cl.Tail())
	assert.Equal(3, cl.Size())

	// [1,24,11,16]
	err = cl.Add(1, nil)
	assert.NoError(err)

	assert.Equal(1, cl.Head())
	assert.Equal(16, cl.Tail())
	assert.Equal(4, cl.Size())

	// [1,24,16]
	err = cl.Remove(11)
	assert.NoError(err)

	assert.Equal(1, cl.Head())
	assert.Equal(16, cl.Tail())
	assert.Equal(3, cl.Size())

	// [16,1,24]
	err = cl.Add(16, nil)
	assert.NoError(err)

	assert.Equal(16, cl.Head())
	assert.Equal(24, cl.Tail())
	assert.Equal(3, cl.Size())

	// [16,1]
	err = cl.Remove(24)
	assert.NoError(err)

	assert.Equal(16, cl.Head())
	assert.Equal(1, cl.Tail())
	assert.Equal(2, cl.Size())

	// [1]
	err = cl.Remove(16)
	assert.NoError(err)

	assert.Equal(1, cl.Head())
	assert.Equal(1, cl.Tail())
	assert.Equal(1, cl.Size())

	// []
	err = cl.Remove(1)
	assert.NoError(err)

	assert.Equal(-1, cl.Head())
	assert.Equal(-1, cl.Tail())
	assert.Equal(0, cl.Size())

	// [16]
	err = cl.Add(16, nil)
	assert.NoError(err)

	assert.Equal(16, cl.Head())
	assert.Equal(16, cl.Tail())
	assert.Equal(1, cl.Size())

	// [16]
	err = cl.Add(16, nil)
	assert.NoError(err)

	assert.Equal(16, cl.Head())
	assert.Equal(16, cl.Tail())
	assert.Equal(1, cl.Size())

	// [11,16]
	err = cl.Add(11, nil)
	assert.NoError(err)

	assert.Equal(11, cl.Head())
	assert.Equal(16, cl.Tail())
	assert.Equal(2, cl.Size())

	// [11]
	err = cl.Remove(16)
	assert.NoError(err)

	assert.Equal(11, cl.Head())
	assert.Equal(11, cl.Tail())
	assert.Equal(1, cl.Size())

	// [16,11]
	err = cl.Add(16, nil)
	assert.NoError(err)

	assert.Equal(16, cl.Head())
	assert.Equal(11, cl.Tail())
	assert.Equal(2, cl.Size())

	// [1,16,11]
	err = cl.Add(1, nil)
	assert.NoError(err)

	assert.Equal(1, cl.Head())
	assert.Equal(11, cl.Tail())
	assert.Equal(3, cl.Size())

	// [11,1,16]
	err = cl.Add(11, nil)
	assert.NoError(err)

	assert.Equal(11, cl.Head())
	assert.Equal(16, cl.Tail())
	assert.Equal(3, cl.Size())

	// [1,11,16]
	err = cl.Add(1, nil)
	assert.NoError(err)

	assert.Equal(1, cl.Head())
	assert.Equal(16, cl.Tail())
	assert.Equal(3, cl.Size())

	// [2,1,11,16]
	err = cl.Add(2, nil)
	assert.NoError(err)

	assert.Equal(2, cl.Head())
	assert.Equal(16, cl.Tail())
	assert.Equal(4, cl.Size())

	// [3,2,1,11,16]
	err = cl.Add(3, nil)
	assert.NoError(err)

	assert.Equal(3, cl.Head())
	assert.Equal(16, cl.Tail())
	assert.Equal(5, cl.Size())

	// [4,3,2,1,11]
	err = cl.Add(4, nil)
	assert.NoError(err)

	assert.Equal(4, cl.Head())
	assert.Equal(11, cl.Tail())
	assert.Equal(5, cl.Size())

	// [5,4,3,2,1]
	err = cl.Add(5, nil)
	assert.NoError(err)

	assert.Equal(5, cl.Head())
	assert.Equal(1, cl.Tail())
	assert.Equal(5, cl.Size())

	// [6,5,4,3,2]
	err = cl.Add(6, nil)
	assert.NoError(err)

	assert.Equal(6, cl.Head())
	assert.Equal(2, cl.Tail())
	assert.Equal(5, cl.Size())

	// [2,6,5,4,3]
	err = cl.Add(2, nil)
	assert.NoError(err)

	assert.Equal(2, cl.Head())
	assert.Equal(3, cl.Tail())
	assert.Equal(5, cl.Size())

	// [4,2,6,5,3]
	err = cl.Add(4, nil)
	assert.NoError(err)

	assert.Equal(4, cl.Head())
	assert.Equal(3, cl.Tail())
	assert.Equal(5, cl.Size())
}
