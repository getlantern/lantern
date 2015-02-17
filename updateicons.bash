#!/bin/bash

go-bindata -nomemcopy -nocompress -pkg main -o src/github.com/getlantern/flashlight/icons.go -prefix src/github.com/getlantern/flashlight/ src/github.com/getlantern/flashlight/icons