#!/bin/bash

go install github.com/getlantern/tarfs/tarfs
tarfs -pkg main resources > resources.go
go build && ./demo