package rotator

import (
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
)

const (
	path = "test_size.log"
)

func cleanup(t *testing.T) {
	if err := os.Remove(path); err != nil {
		t.Logf("Unable to remove file: %v", err)
	}
	if err := os.Remove(path + ".1"); err != nil {
		t.Logf("Unable to remove file: %v", err)
	}
	if err := os.Remove(path + ".2"); err != nil {
		t.Logf("Unable to remove file: %v", err)
	}
	if err := os.Remove(path + ".3"); err != nil {
		t.Logf("Unable to remove file: %v", err)
	}
}

func TestSizeNormalOutput(t *testing.T) {

	cleanup(t)
	defer cleanup(t)

	rotator := NewSizeRotator(path)
	defer func() {
		go func() {
			if err := rotator.Close(); err != nil {
				t.Fatalf("Unable to close rotator: %v", err)
			}
		}()
	}()

	if _, err := rotator.WriteString("SAMPLE LOG"); err != nil {
		t.Fatalf("Unable to write string: %v", err)
	}

	file, err := os.OpenFile(path, os.O_RDONLY, 0644)
	if err != nil {
		panic(err)
	}
	defer func() {
		if err := file.Close(); err != nil {
			t.Fatalf("Unable to close file: %v", err)
		}
	}()

	b := make([]byte, 10)
	if _, err := file.Read(b); err != nil {
		t.Fatalf("Unable to read: %v", err)
	}
	assert.Equal(t, "SAMPLE LOG", string(b))

	if _, err := rotator.WriteString("|NEXT LOG"); err != nil {
		t.Fatalf("Unable to write string: %v", err)
	}
	if _, err := rotator.WriteString("|LAST LOG"); err != nil {
		t.Fatalf("Unable to write string: %v", err)
	}

	b = make([]byte, 28)
	if _, err := file.ReadAt(b, 0); err != nil {
		t.Fatalf("Unable to read file: %v", err)
	}

	assert.Equal(t, "SAMPLE LOG|NEXT LOG|LAST LOG", string(b))

}

func TestSizeRotation(t *testing.T) {

	cleanup(t)
	defer cleanup(t)

	rotator := NewSizeRotator(path)
	rotator.RotationSize = 10
	defer func() {
		go func() {
			if err := rotator.Close(); err != nil {
				t.Fatalf("Unable to close rotator: %v", err)
			}
		}()
	}()

	if _, err := rotator.WriteString("0123456789"); err != nil {
		t.Fatalf("Unable to write string: %v", err)
	}
	// it should not be rotated
	stat, _ := os.Lstat(path + ".1")
	assert.Nil(t, stat)

	// it should be rotated
	if _, err := rotator.WriteString("0123456789"); err != nil {
		t.Fatalf("Unable to close rotator: %v", err)
	}
	stat, _ = os.Lstat(path)
	assert.NotNil(t, stat)
	assert.EqualValues(t, stat.Size(), 10)

	stat, _ = os.Lstat(path + ".1")
	assert.NotNil(t, stat)
	assert.EqualValues(t, stat.Size(), 10)

}

func TestSizeAppendExist(t *testing.T) {

	cleanup(t)
	defer cleanup(t)

	file, _ := os.OpenFile(path, os.O_WRONLY|os.O_CREATE, 0644)
	// size should be 5;
	if _, err := file.WriteString("01234"); err != nil {
		t.Fatalf("Unable to write string: %v", err)
	}
	if err := file.Close(); err != nil {
		t.Fatalf("Unable to close file: %v", err)
	}

	rotator := NewSizeRotator(path)
	rotator.RotationSize = 10
	_, err := rotator.WriteString("56789012")
	assert.Nil(t, err)

	stat, _ := os.Lstat(path)
	assert.NotNil(t, stat)
	assert.EqualValues(t, 8, stat.Size())

	stat, _ = os.Lstat(path + ".1")
	assert.NotNil(t, stat)
	assert.EqualValues(t, 5, stat.Size())

}

func TestSizeMaxRotation(t *testing.T) {

	cleanup(t)
	defer cleanup(t)

	rotator := NewSizeRotator(path)
	rotator.RotationSize = 10
	rotator.MaxRotation = 3
	defer func() {
		go func() {
			if err := rotator.Close(); err != nil {
				t.Fatalf("Unable to close rotator: %v", err)
			}
		}()
	}()

	if _, err := rotator.WriteString("0123456789"); err != nil {
		t.Fatalf("Unable to write string: %v", err)
	}
	stat, _ := os.Lstat(path + ".1")
	assert.Nil(t, stat)

	if _, err := rotator.WriteString("0123456789"); err != nil {
		t.Fatalf("Unable to close rotator: %v", err)
	}
	if _, err := rotator.WriteString("0123456789"); err != nil {
		t.Fatalf("Unable to close rotator: %v", err)
	}
	if _, err := rotator.WriteString("0123456789"); err != nil {
		t.Fatalf("Unable to close rotator: %v", err)
	}

	stat, _ = os.Lstat(path + ".1")
	assert.NotNil(t, stat)
	assert.EqualValues(t, stat.Size(), 10)

	stat, _ = os.Lstat(path + ".2")
	assert.NotNil(t, stat)
	assert.EqualValues(t, stat.Size(), 10)

	stat, _ = os.Lstat(path + ".3")
	assert.NotNil(t, stat)
	assert.EqualValues(t, stat.Size(), 10)

	// It should overwrite the first log of the rotation
	rotator.WriteString("ASDF")

	stat, _ = os.Lstat(path)
	assert.NotNil(t, stat)
	assert.EqualValues(t, stat.Size(), 4)
}
