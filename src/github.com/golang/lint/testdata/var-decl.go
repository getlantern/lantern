// Test for redundant type declaration.

// Package foo ...
package foo

import "fmt"
import "net/http"

// Q is a test type.
type Q bool

var myInt int = 7                           // MATCH /should.*int.*myInt.*inferred/
var mux *http.ServeMux = http.NewServeMux() // MATCH /should.*\*http\.ServeMux.*inferred/

var myZeroInt int = 0         // MATCH /should.*= 0.*myZeroInt.*zero value/
var myZeroFlt float32 = 0.    // MATCH /should.*= 0\..*myZeroFlt.*zero value/
var myZeroF64 float64 = 0.0   // MATCH /should.*= 0\..*myZeroF64.*zero value/
var myZeroImg complex64 = 0i  // MATCH /should.*= 0i.*myZeroImg.*zero value/
var myZeroStr string = ""     // MATCH /should.*= "".*myZeroStr.*zero value/
var myZeroRaw string = ``     // MATCH /should.*= ``.*myZeroRaw.*zero value/
var myZeroPtr *Q = nil        // MATCH /should.*= nil.*myZeroPtr.*zero value/
var myZeroRune rune = '\x00'  // MATCH /should.*= '\\x00'.*myZeroRune.*zero value/
var myZeroRune2 rune = '\000' // MATCH /should.*= '\\000'.*myZeroRune2.*zero value/

// No warning because there's no type on the LHS
var x = 0

// This shouldn't get a warning because there's no initial values.
var str fmt.Stringer

// No warning because this is a const.
const k uint64 = 7

const num = 123

// No warning because the var's RHS is known to be an untyped const.
var flags uint32 = num

// No warnings because the RHS is an ideal int, and the LHS is a different int type.
var userID int64 = 1235
var negID int64 = -1
var parenID int64 = (17)
var crazyID int64 = -(-(-(-9)))

// Same, but for strings and floats.
type stringT string
type floatT float64

var stringV stringT = "abc"
var floatV floatT = 123.45

// No warning because the LHS names an interface type.
var data interface{} = googleIPs
var googleIPs []int

// No warning because it's a common idiom for interface satisfaction.
var _ Server = (*serverImpl)(nil)

// Server is a test type.
type Server interface{}
type serverImpl struct{}

// LHS is a different type than the RHS.
var myStringer fmt.Stringer = q(0)

// We don't figure out the true types of LHS and RHS here,
// but io.Writer is a known weaker type for many common uses,
// so the suggestion should be suppressed here.
var out io.Writer = os.Stdout

// This next one, however, should be type checked.
var out2 io.Writer = newWriter() // MATCH /should.*io\.Writer/

func newWriter() io.Writer { return nil }

var y string = q(1).String() // MATCH /should.*string/

type q int

func (q) String() string { return "I'm a q" }
