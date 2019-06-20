# Copyright 2012 The Go Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

TMP=/tmp/mksyscall_windows

zwinapi_windows.go: event.go eventlog.go registry.go security.go service.go syscall.go
	go build -o $(TMP) $(GOROOT)/src/pkg/syscall/mksyscall_windows.go
	GOOS=windows $(TMP) $^ | gofmt > $@
	rm $(TMP)
