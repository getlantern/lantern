#!/bin/bash

go-bindata-assetfs -pkg "http" -nocompress -nomemcopy src/github.com/getlantern/ui/app/... && mv bindata_assetfs.go src/github.com/getlantern/flashlight/http
