gls [![GoDoc](https://godoc.org/github.com/tylerb/gls?status.png)](http://godoc.org/github.com/tylerb/gls) [![Build Status](https://drone.io/github.com/tylerb/gls/status.png)](https://drone.io/github.com/tylerb/gls/latest) [![Coverage Status](https://coveralls.io/repos/tylerb/gls/badge.svg?branch=master)](https://coveralls.io/r/tylerb/gls?branch=master)
===

GoRoutine local storage using GoRoutine IDs

This package is heavily inspired by [jtolds](https://github.com/jtolds)' [gls](https://github.com/jtolds/gls) package.

I made my own version of jtolds' package because [Brad Fitzpatrick](https://github.com/bradfitz) [created a function](https://github.com/bradfitz/http2/blob/dc0c5c000ec33e263612939744d51a3b68b9cece/gotrack.go) to get the current GoRoutine ID. Am I a horrible person for using this function? Probably.

### Why is this useful? ###

So far, the only thing I'm using it for is storing a unique identifier for a given HTTP request so I can track its progress through my code via logging. I felt this approach was easier and less messy than refactoring every function to take some kind of context or identifier.

Enjoy!
