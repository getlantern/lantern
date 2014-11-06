[![GoDoc](https://godoc.org/gopkg.in/stack.v0?status.svg)](https://godoc.org/gopkg.in/stack.v0) [![Build Status](https://travis-ci.org/go-stack/stack.svg?branch=master)](https://travis-ci.org/go-stack/stack)

Package stack implements utilities to capture, manipulate, and format call stacks. It provides a simpler API than package runtime.

The implementation takes care of the minutia and special cases of interpreting the program counter (pc) values returned by runtime.Callers.

Package stack's types implement fmt.Formatter, which provides a simple and flexible way to declaratively configure formatting when used with logging or error tracking packages.
