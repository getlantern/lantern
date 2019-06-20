package rotator

import (
	"os"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestRotationNormalOutput(t *testing.T) {

	path := "test_daily.log"

	stat, _ := os.Lstat(path)
	if stat != nil {
		if err := os.Remove(path); err != nil {
			t.Fatalf("Unable to remove file: %v", err)
		}
	}

	rotator := NewDailyRotator(path)
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
		t.Fatalf("Unable to read file: %v", err)
	}
	assert.Equal(t, "SAMPLE LOG", string(b))

	if _, err := rotator.WriteString("\nNEXT LOG"); err != nil {
		t.Fatalf("Unable to write string: %v", err)
	}
	if _, err := rotator.WriteString("\nLAST LOG"); err != nil {
		t.Fatalf("Unable to write string: %v", err)
	}

	b = make([]byte, 28)
	if _, err := file.ReadAt(b, 0); err != nil {
		t.Fatalf("Unable to read file: %v", err)
	}

	assert.Equal(t, "SAMPLE LOG\nNEXT LOG\nLAST LOG", string(b))

}

func TestDailyRotationOnce(t *testing.T) {

	path := "test_daily.log"

	stat, _ := os.Lstat(path)
	if stat != nil {
		if err := os.Remove(path); err != nil {
			t.Fatalf("Unable to remove: %v", err)
		}
	}

	now := time.Now()

	rotator := NewDailyRotator(path)
	defer func() {
		go func() {
			if err := rotator.Close(); err != nil {
				t.Fatalf("Unable to close rotator: %v", err)
			}
		}()
	}()

	rotator.Now = now
	if _, err := rotator.WriteString("SAMPLE LOG"); err != nil {
		t.Fatalf("Unable to write string: %v", err)
	}

	// simulate next day
	rotator.Now = time.Unix(now.Unix()+86400, 0)
	if _, err := rotator.WriteString("NEXT LOG"); err != nil {
		t.Fatalf("Unable to write string: %v", err)
	}

	stat, _ = os.Lstat(path + "." + now.Format(dateFormat))

	assert.NotNil(t, stat)

	if err := os.Remove(path); err != nil {
		t.Fatalf("Unable to remove file: %v", err)
	}
	if err := os.Remove(path + "." + now.Format(dateFormat)); err != nil {
		t.Fatalf("Unable to remove file: %v", err)
	}
}

func TestDailyRotationAtOpen(t *testing.T) {

	path := "test_daily.log"

	stat, _ := os.Lstat(path)
	if stat != nil {
		if err := os.Remove(path); err != nil {
			t.Fatalf("Unable to remove file: %v", err)
		}
	}

	rotator := NewDailyRotator(path)
	if _, err := rotator.WriteString("FIRST LOG"); err != nil {
		t.Fatalf("Unable to write string: %v", err)
	}
	if err := rotator.Close(); err != nil {
		t.Fatalf("Unable to  close rotator: %v", err)
	}

	now := time.Now()

	// simulate next day
	rotator = NewDailyRotator(path)
	defer func() {
		go func() {
			if err := rotator.Close(); err != nil {
				t.Fatalf("Unable to close rotator: %v", err)
			}
		}()
	}()

	rotator.Now = time.Unix(now.Unix()+86400, 0)
	if _, err := rotator.WriteString("NEXT LOG"); err != nil {
		t.Fatalf("Unable to write string: %v", err)
	}

	stat, _ = os.Lstat(path + "." + now.Format(dateFormat))

	assert.NotNil(t, stat)

	if err := os.Remove(path); err != nil {
		t.Fatalf("Unable to remove file: %v", err)
	}
	if err := os.Remove(path + "." + now.Format(dateFormat)); err != nil {
		t.Fatalf("Unable to remove file: %v", err)
	}
}

func TestDailyRotationError(t *testing.T) {

	path := "test_daily.log"

	stat, _ := os.Lstat(path)
	if stat != nil {
		if err := os.Remove(path); err != nil {
			t.Fatalf("Unable to remove file: %v", err)
		}
	}

	now := time.Now()

	rotator := NewDailyRotator(path)
	if _, err := rotator.WriteString("FIRST LOG"); err != nil {
		t.Fatalf("Unable to write string: %v", err)
	}
	// Simulate rotation
	rotator.Now = time.Unix(now.Unix()+86400, 0)
	if _, err := rotator.WriteString("SECOND LOG"); err != nil {
		t.Fatalf("Unable to write string: %v", err)
	}
	if err := rotator.Close(); err != nil {
		t.Fatalf("Unable to close rotator: %v", err)
	}

	rotator = NewDailyRotator(path)
	defer func() {
		go func() {
			if err := rotator.Close(); err != nil {
				t.Fatalf("Unable to close rotator: %v", err)
			}
		}()
	}()
	if _, err := rotator.WriteString("FIRST LOG"); err != nil {
		t.Fatalf("Unable to write string: %v", err)
	}
	// Simulate rotation twice
	rotator.Now = time.Unix(now.Unix()+86400, 0)
	_, err := rotator.WriteString("SECOND LOG")

	assert.Nil(t, err)

	if err := os.Remove(path); err != nil {
		t.Fatalf("Unable to remove file: %v", err)
	}
	if err := os.Remove(path + "." + now.Format(dateFormat)); err != nil {
		t.Fatalf("Unable to remove file: %v", err)
	}
}
