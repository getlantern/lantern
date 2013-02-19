package otto

import (
	. "github.com/robertkrimen/terst"
	"testing"
)

func TestNumber_toString(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
        new Number(451).toString();
    `, "451")

	test(`
        new Number(451).toString(10);
    `, "451")

	test(`
        new Number(451).toString(8);
    `, "703")

	test(`raise:
        new Number(451).toString(1);
    `, "RangeError: RangeError: toString() radix must be between 2 and 36")

	test(`raise:
        new Number(451).toString(Infinity);
    `, "RangeError: RangeError: toString() radix must be between 2 and 36")
}
