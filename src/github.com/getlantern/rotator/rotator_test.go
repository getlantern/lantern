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
		os.Remove(path)
	}

	var r Rotator

	// assign NewDailyRotator
	r = NewDailyRotator(path)

	// 1. Close method
	defer r.Close()

	// 2. Write method
	r.Write(bytes.NewBufferString("SAMPLE LOG").Bytes())

	file, err := os.OpenFile(path, os.O_RDONLY, 0644)
	if err != nil {
		panic(err)
	}
	defer file.Close()

	b := make([]byte, 10)
	file.Read(b)
	assert.Equal(t, "SAMPLE LOG", string(b))

	// 3. WriteString method
	r.WriteString("\nNEXT LOG")
	r.WriteString("\nLAST LOG")

	b = make([]byte, 28)
	file.ReadAt(b, 0)

	assert.Equal(t, "SAMPLE LOG\nNEXT LOG\nLAST LOG", string(b))

}

func TestRotatorInterfaceBySizeRotator(t *testing.T) {

	path := "test_size.log"

	stat, _ := os.Lstat(path)
	if stat != nil {
		os.Remove(path)
	}

	var r Rotator

	// assign NewSizeRotator
	r = NewSizeRotator(path)

	// 1. Close method
	defer r.Close()

	// 2. Write method
	r.Write(bytes.NewBufferString("SAMPLE LOG").Bytes())

	file, err := os.OpenFile(path, os.O_RDONLY, 0644)
	if err != nil {
		panic(err)
	}
	defer file.Close()

	b := make([]byte, 10)
	file.Read(b)
	assert.Equal(t, "SAMPLE LOG", string(b))

	// 3. WriteString method
	r.WriteString("|NEXT LOG")
	r.WriteString("|LAST LOG")

	b = make([]byte, 28)
	file.ReadAt(b, 0)

	assert.Equal(t, "SAMPLE LOG|NEXT LOG|LAST LOG", string(b))
}
