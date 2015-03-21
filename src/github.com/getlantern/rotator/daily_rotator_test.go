package rotator

import (
	"github.com/stretchr/testify/assert"
	"os"
	"testing"
	"time"
)

func TestRotationNormalOutput(t *testing.T) {

	path := "test_daily.log"

	stat, _ := os.Lstat(path)
	if stat != nil {
		os.Remove(path)
	}

	rotator := NewDailyRotator(path)
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

	rotator.WriteString("\nNEXT LOG")
	rotator.WriteString("\nLAST LOG")

	b = make([]byte, 28)
	file.ReadAt(b, 0)

	assert.Equal(t, "SAMPLE LOG\nNEXT LOG\nLAST LOG", string(b))

}

func TestDailyRotationOnce(t *testing.T) {

	path := "test_daily.log"

	stat, _ := os.Lstat(path)
	if stat != nil {
		os.Remove(path)
	}

	now := time.Now()

	rotator := NewDailyRotator(path)
	defer rotator.Close()

	rotator.Now = now
	rotator.WriteString("SAMPLE LOG")

	// simulate next day
	rotator.Now = time.Unix(now.Unix()+86400, 0)
	rotator.WriteString("NEXT LOG")

	stat, _ = os.Lstat(path + "." + now.Format(dateFormat))

	assert.NotNil(t, stat)

	os.Remove(path)
	os.Remove(path + "." + now.Format(dateFormat))
}

func TestDailyRotationAtOpen(t *testing.T) {

	path := "test_daily.log"

	stat, _ := os.Lstat(path)
	if stat != nil {
		os.Remove(path)
	}

	rotator := NewDailyRotator(path)
	rotator.WriteString("FIRST LOG")
	rotator.Close()

	now := time.Now()

	// simulate next day
	rotator = NewDailyRotator(path)
	defer rotator.Close()

	rotator.Now = time.Unix(now.Unix()+86400, 0)
	rotator.WriteString("NEXT LOG")

	stat, _ = os.Lstat(path + "." + now.Format(dateFormat))

	assert.NotNil(t, stat)

	os.Remove(path)
	os.Remove(path + "." + now.Format(dateFormat))
}

func TestDailyRotationError(t *testing.T) {

	path := "test_daily.log"

	stat, _ := os.Lstat(path)
	if stat != nil {
		os.Remove(path)
	}

	now := time.Now()

	rotator := NewDailyRotator(path)
	rotator.WriteString("FIRST LOG")
	// Simulate rotation
	rotator.Now = time.Unix(now.Unix()+86400, 0)
	rotator.WriteString("SECOND LOG")
	rotator.Close()

	rotator = NewDailyRotator(path)
	defer rotator.Close()
	rotator.WriteString("FIRST LOG")
	// Simulate rotation twice
	rotator.Now = time.Unix(now.Unix()+86400, 0)
	_, err := rotator.WriteString("SECOND LOG")

	assert.Nil(t, err)

	os.Remove(path)
	os.Remove(path + "." + now.Format(dateFormat))

}
