# is [![GoDoc](https://godoc.org/github.com/tylerb/is?status.png)](http://godoc.org/github.com/tylerb/is) [![Build Status](https://drone.io/github.com/tylerb/is/status.png)](https://drone.io/github.com/tylerb/is/latest) [![Coverage Status](https://coveralls.io/repos/tylerb/is/badge.svg?branch=master)](https://coveralls.io/r/tylerb/is?branch=master) [![Gitter](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/tylerb/is?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)

Is provides a quick, clean and simple framework for writing Go tests.

## Installation

To install, simply execute:

```
go get gopkg.in/tylerb/is.v1
```

I am using [gopkg.in](http://http://labix.org/gopkg.in) to control releases.

## Usage

Using `Is` is simple:

```go
func TestSomething(t *testing.T) {
	is := is.New(t)

	expected := 10
	result, _ := awesomeFunction()
	is.Equal(expected,result)
}
```

If you'd like a bit more information when a test fails, you may use the `Msg()` method:

```go
func TestSomething(t *testing.T) {
	is := is.New(t)

	expected := 10
	result, details := awesomeFunction()
	is.Msg("result details: %s", details).Equal(expected,result)
}
```

By default, Is fails and stops the test immediately. If you prefer to run multiple assertions to see them all fail at once, use the `Lax` method:

```go
func TestSomething(t *testing.T) {
	is := is.New(t).Lax()

	is.Equal(1,someFunc()) // if this fails, a message is printed and the test continues
	is.Equal(2,someOtherFunc()) // if this fails, a message is printed and the test continues
```

If you are using a relaxed instance of Is, you can switch it back to strict mode with `Strict`. This is useful when an assertion *must* be correct, or subsequent calls will panic:

```go
func TestSomething(t *testing.T) {
	is := is.New(t).Lax()

	results := someFunc()
	is.Strict().Equal(len(results),3) // if this fails, a message is printed and testing stops
	is.Equal(results[0],1) // if this fails, a message is printed and testing continues
	is.Equal(results[1],2)
	is.Equal(results[2],3)
```

Strict mode, in this case, applies only to the line on which it is invoked, as we don't overwrite our copy of the `is` variable.

## Contributing

If you would like to contribute, please:

1. Create a GitHub issue regarding the contribution. Features and bugs should be discussed beforehand.
2. Fork the repository.
3. Create a pull request with your solution. This pull request should reference and close the issues (Fix #2).

All pull requests should:

1. Pass [gometalinter -t .](https://github.com/alecthomas/gometalinter) with no warnings.
2. Be `go fmt` formatted.
