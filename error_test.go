package otto

import (
	. "./terst"
	"testing"
)

func TestError_instanceof(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`
        (new TypeError()) instanceof Error
    `, "true")
}
