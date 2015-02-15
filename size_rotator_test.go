package rotator

import (
	"github.com/stretchr/testify/assert"
	"os"
	"testing"
)

const (
	path = "test_size.log"
)

func cleanup() {
	os.Remove(path)
	os.Remove(path + ".1")
	os.Remove(path + ".2")
	os.Remove(path + ".3")
}

func TestSizeNormalOutput(t *testing.T) {

	cleanup()
	defer cleanup()

	rotator := NewSizeRotator(path)
	defer rotator.Close()

	rotator.WriteString("SAMPLE LOG")

	file, err := os.OpenFile(path, os.O_RDONLY, 0644)
	if err != nil {
		panic(err)
	}
	defer file.Close()

	b := make([]byte, 10)
	file.Read(b)
	assert.Equal(t, "SAMPLE LOG", string(b))

	rotator.WriteString("|NEXT LOG")
	rotator.WriteString("|LAST LOG")

	b = make([]byte, 28)
	file.ReadAt(b, 0)

	assert.Equal(t, "SAMPLE LOG|NEXT LOG|LAST LOG", string(b))

}

func TestSizeRotation(t *testing.T) {

	cleanup()
	defer cleanup()

	rotator := NewSizeRotator(path)
	rotator.RotationSize = 10
	defer rotator.Close()

	rotator.WriteString("0123456789")
	// it should not be rotated
	stat, _ := os.Lstat(path + ".1")
	assert.Nil(t, stat)

	// it should be rotated
	rotator.WriteString("0123456789")
	stat, _ = os.Lstat(path)
	assert.NotNil(t, stat)
	assert.Equal(t, stat.Size(), 10)

	stat, _ = os.Lstat(path + ".1")
	assert.NotNil(t, stat)
	assert.Equal(t, stat.Size(), 10)

}

func TestSizeAppendExist(t *testing.T) {

	cleanup()
	defer cleanup()

	file, _ := os.OpenFile(path, os.O_WRONLY|os.O_CREATE, 0644)
	file.WriteString("01234") // size should be 5
	file.Close()

	rotator := NewSizeRotator(path)
	rotator.RotationSize = 10
	_, err := rotator.WriteString("56789012")
	assert.Nil(t, err)

	stat, _ := os.Lstat(path)
	assert.NotNil(t, stat)
	assert.Equal(t, 8, stat.Size())

	stat, _ = os.Lstat(path + ".1")
	assert.NotNil(t, stat)
	assert.Equal(t, 5, stat.Size())

}

func TestSizeMaxRotation(t *testing.T) {

	cleanup()
	defer cleanup()

	rotator := NewSizeRotator(path)
	rotator.RotationSize = 10
	rotator.MaxRotation = 3
	defer rotator.Close()

	rotator.WriteString("0123456789")
	stat, _ := os.Lstat(path + ".1")
	assert.Nil(t, stat)

	rotator.WriteString("0123456789")
	rotator.WriteString("0123456789")
	rotator.WriteString("0123456789")

	stat, _ = os.Lstat(path + ".1")
	assert.NotNil(t, stat)
	assert.Equal(t, stat.Size(), 10)

	stat, _ = os.Lstat(path + ".2")
	assert.NotNil(t, stat)
	assert.Equal(t, stat.Size(), 10)

	stat, _ = os.Lstat(path + ".3")
	assert.NotNil(t, stat)
	assert.Equal(t, stat.Size(), 10)

	// it should fail rotation
	_, err := rotator.WriteString("0123456789")
	assert.NotNil(t, err)
	assert.Equal(t, err.Error(), "rotation count has been exceeded")
}
