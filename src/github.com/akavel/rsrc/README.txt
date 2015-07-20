rsrc - Tool for embedding binary resources in Go programs.

INSTALL: go get github.com/akavel/rsrc

PREBUILT BINARIES for Windows/Linux/MacOSX available via 3rd party site:
                  http://gobuild.io/download/github.com/akavel/rsrc

USAGE:

rsrc [-manifest FILE.exe.manifest] [-ico FILE.ico[,FILE2.ico...]] -o FILE.syso
  Generates a .syso file with specified resources embedded in .rsrc section.
  The .syso file can be linked by Go linker when building Win32 executables.
  Icon embedded this way will show up on application's .exe instead of empty icon.
  Manifest file embedded this way will be recognized and detected by Windows.

rsrc -data FILE.dat -o FILE.syso > FILE.c
  Generates a .syso file with specified opaque binary blob embedded,
  together with related .c file making it possible to access from Go code.
  Theoretically cross-platform, but reportedly cannot compile together with cgo.

The generated *.syso and *.c files should get automatically recognized
by 'go build' command and linked into an executable/library, as long as
there are any *.go files in the same directory.

NOTE: starting with Go 1.4+, *.c files reportedly won't be linkable any more,
      see: https://codereview.appspot.com/149720043

OPTIONS:
  -data="": path to raw data file to embed
  -ico="": comma-separated list of paths to .ico files to embed
  -manifest="": path to a Windows manifest file to embed
  -o="rsrc.syso": name of output COFF (.res or .syso) file

Based on ideas presented by Minux.

In case anything does not work, it'd be nice if you could report (either via Github
issues, or via email to czapkofan@gmail.com), and please attach the input file(s)
which resulted in a problem, plus error message & symptoms, and/or any other details.

TODO MAYBE/LATER:
- fix or remove FIXMEs

LICENSE: MIT
  Copyright 2013-2014 The rsrc Authors.

http://github.com/akavel/rsrc
