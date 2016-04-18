package byteexec

import (
	"fmt"
	"io/ioutil"
	"os"
	"runtime"
	"sync"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

const (
	program = "helloworld"

	concurrency = 10
)

func TestExec(t *testing.T) {
	data, err := Asset(program)
	if err != nil {
		t.Fatalf("Unable to read helloworld program: %s", err)
	}
	be := createByteExec(t, data)

	// Concurrently create some other BEs and make sure they don't get errors
	var wg sync.WaitGroup
	wg.Add(concurrency)
	for i := 0; i < concurrency; i++ {
		_, err := New(data, program)
		assert.NoError(t, err, "Concurrent New should have succeeded")
		wg.Done()
	}
	wg.Wait()

	originalInfo := testByteExec(t, be)

	// Recreate be and make sure file is reused
	be = createByteExec(t, data)
	updatedInfo := testByteExec(t, be)
	assert.Equal(t, originalInfo.ModTime(), updatedInfo.ModTime(), "File modification time should be unchanged after creating new ByteExec")

	// Now mess with the file permissions and make sure that we can still run
	err = os.Chmod(be.Filename, 0655)
	if err != nil {
		t.Fatalf("Unable to chmod test executable %s: %s", be.Filename, err)
	}
	be = createByteExec(t, data)
	updatedInfo = testByteExec(t, be)
	if runtime.GOOS != "windows" {
		// On windows, file mode doesn't work as expected, so check only on
		// non-windows platforms
		assert.Equal(t, fileMode, updatedInfo.Mode(), fmt.Sprintf("Executable file should have been chmodded. File mode was %v instead of %v", updatedInfo.Mode(), fileMode))
	}

	// Now mess with the file contents and make sure it gets overwritten on next
	// ByteExec
	if err := ioutil.WriteFile(be.Filename, []byte("Junk"), 0755); err != nil {
		t.Fatalf("Unable to write file: %v", err)
	}
	be = createByteExec(t, data)
	updatedInfo = testByteExec(t, be)
	assert.NotEqual(t, originalInfo.ModTime(), updatedInfo.ModTime(), "File modification time should be changed after creating new ByteExec on bad data")
}

func createByteExec(t *testing.T, data []byte) *Exec {
	// Sleep 1 second to give file timestamp a chance to increase
	time.Sleep(1 * time.Second)

	be, err := New(data, program)
	if err != nil {
		t.Fatalf("Unable to create new ByteExec: %s", err)
	}
	return be
}

func testByteExec(t *testing.T, be *Exec) os.FileInfo {
	cmd := be.Command()
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Errorf("Unable to run helloworld program: %s", err)
	}
	assert.Equal(t, "Hello world"+linefeed, string(out), "Should receive expected output from helloworld program")

	t.Log(be.Filename)
	fileInfo, err := os.Stat(be.Filename)
	if err != nil {
		t.Fatalf("Unable to re-stat file %s: %s", be.Filename, err)
	}
	return fileInfo
}
