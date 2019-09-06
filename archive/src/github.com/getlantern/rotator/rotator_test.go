package rotator

import (
	"bytes"
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestRotatorInterfaceByDailyRotator(t *testing.T) {

	path := "test_daily.log"

	stat, _ := os.Lstat(path)
	if stat != nil {
		if err := os.Remove(path); err != nil {
			t.Fatalf("Unable to remove path: %v", err)
		}
	}

	var r Rotator

	// assign NewDailyRotator
	r = NewDailyRotator(path)

	// 1. Close method
	defer func() {
		if err := r.Close(); err != nil {
			t.Fatalf("Unable to close rotator: %v", err)
		}
	}()

	// 2. Write method
	if _, err := r.Write(bytes.NewBufferString("SAMPLE LOG").Bytes()); err != nil {
		t.Fatalf("Unable to write: %v", err)
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
		t.Fatalf("Unable to read file: %v", err)
	}
	assert.Equal(t, "SAMPLE LOG", string(b))

	// 3. WriteString method
	if _, err := r.WriteString("\nNEXT LOG"); err != nil {
		t.Fatalf("Unable to write string: %v", err)
	}
	if _, err := r.WriteString("\nLAST LOG"); err != nil {
		t.Fatalf("Unable to write string: %v", err)
	}

	b = make([]byte, 28)
	if _, err := file.ReadAt(b, 0); err != nil {
		t.Fatalf("Unable to read: %v", err)
	}

	assert.Equal(t, "SAMPLE LOG\nNEXT LOG\nLAST LOG", string(b))

}

func TestRotatorInterfaceBySizeRotator(t *testing.T) {

	path := "test_size.log"

	stat, _ := os.Lstat(path)
	if stat != nil {
		if err := os.Remove(path); err != nil {
			t.Fatalf("Unable to remove file: %v", err)
		}
	}

	var r Rotator

	// assign NewSizeRotator
	r = NewSizeRotator(path)

	// 1. Close method
	defer func() {
		if err := r.Close(); err != nil {
			t.Fatalf("Unable to close rotator: %v", err)
		}
	}()

	// 2. Write method
	if _, err := r.Write(bytes.NewBufferString("SAMPLE LOG").Bytes()); err != nil {
		t.Fatalf("Unable to write: %v", err)
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
		t.Fatalf("Unable to read file: %v", err)
	}
	assert.Equal(t, "SAMPLE LOG", string(b))

	// 3. WriteString method
	if _, err := r.WriteString("|NEXT LOG"); err != nil {
		t.Fatalf("Unable to write: %v", err)
	}
	if _, err := r.WriteString("|LAST LOG"); err != nil {
		t.Fatalf("Unable to write: %v", err)
	}

	b = make([]byte, 28)
	if _, err := file.ReadAt(b, 0); err != nil {
		t.Fatalf("Unable to read: %v", err)
	}

	assert.Equal(t, "SAMPLE LOG|NEXT LOG|LAST LOG", string(b))
}
