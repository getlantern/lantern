package main

import (
	"bytes"
	"fmt"
	"go/build"
	"io/ioutil"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"unicode/utf8"
)

// our own readdir, which skips the files it cannot lstat
func readdir(name string) ([]os.FileInfo, error) {
	f, err := os.Open(name)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	names, err := f.Readdirnames(-1)
	if err != nil {
		return nil, err
	}

	out := make([]os.FileInfo, 0, len(names))
	for _, lname := range names {
		s, err := os.Lstat(filepath.Join(name, lname))
		if err != nil {
			continue
		}
		out = append(out, s)
	}
	return out, nil
}

// returns truncated 'data' and amount of bytes skipped (for cursor pos adjustment)
func filter_out_shebang(data []byte) ([]byte, int) {
	if len(data) > 2 && data[0] == '#' && data[1] == '!' {
		newline := bytes.Index(data, []byte("\n"))
		if newline != -1 && len(data) > newline+1 {
			return data[newline+1:], newline + 1
		}
	}
	return data, 0
}

func file_exists(filename string) bool {
	_, err := os.Stat(filename)
	if err != nil {
		return false
	}
	return true
}

func char_to_byte_offset(s []byte, offset_c int) (offset_b int) {
	for offset_b = 0; offset_c > 0 && offset_b < len(s); offset_b++ {
		if utf8.RuneStart(s[offset_b]) {
			offset_c--
		}
	}
	return offset_b
}

func xdg_home_dir() string {
	xdghome := os.Getenv("XDG_CONFIG_HOME")
	if xdghome == "" {
		xdghome = filepath.Join(os.Getenv("HOME"), ".config")
	}
	return xdghome
}

func has_prefix(s, prefix string, ignorecase bool) bool {
	if ignorecase {
		s = strings.ToLower(s)
		prefix = strings.ToLower(prefix)
	}
	return strings.HasPrefix(s, prefix)
}

//-------------------------------------------------------------------------
// print_backtrace
//
// a nicer backtrace printer than the default one
//-------------------------------------------------------------------------

var g_backtrace_mutex sync.Mutex

func print_backtrace(err interface{}) {
	g_backtrace_mutex.Lock()
	defer g_backtrace_mutex.Unlock()
	fmt.Printf("panic: %v\n", err)
	i := 2
	for {
		pc, file, line, ok := runtime.Caller(i)
		if !ok {
			break
		}
		f := runtime.FuncForPC(pc)
		fmt.Printf("%d(%s): %s:%d\n", i-1, f.Name(), file, line)
		i++
	}
	fmt.Println("")
}

//-------------------------------------------------------------------------
// File reader goroutine
//
// It's a bad idea to block multiple goroutines on file I/O. Creates many
// threads which fight for HDD. Therefore only single goroutine should read HDD
// at the same time.
//-------------------------------------------------------------------------

type file_read_request struct {
	filename string
	out      chan file_read_response
}

type file_read_response struct {
	data  []byte
	error error
}

type file_reader_type struct {
	in chan file_read_request
}

func new_file_reader() *file_reader_type {
	this := new(file_reader_type)
	this.in = make(chan file_read_request)
	go func() {
		var rsp file_read_response
		for {
			req := <-this.in
			rsp.data, rsp.error = ioutil.ReadFile(req.filename)
			req.out <- rsp
		}
	}()
	return this
}

func (this *file_reader_type) read_file(filename string) ([]byte, error) {
	req := file_read_request{
		filename,
		make(chan file_read_response),
	}
	this.in <- req
	rsp := <-req.out
	return rsp.data, rsp.error
}

var file_reader = new_file_reader()

//-------------------------------------------------------------------------
// copy of the build.Context without func fields
//-------------------------------------------------------------------------

type go_build_context struct {
	GOARCH        string
	GOOS          string
	GOROOT        string
	GOPATH        string
	CgoEnabled    bool
	UseAllFiles   bool
	Compiler      string
	BuildTags     []string
	ReleaseTags   []string
	InstallSuffix string
}

func pack_build_context(ctx *build.Context) go_build_context {
	return go_build_context{
		GOARCH:        ctx.GOARCH,
		GOOS:          ctx.GOOS,
		GOROOT:        ctx.GOROOT,
		GOPATH:        ctx.GOPATH,
		CgoEnabled:    ctx.CgoEnabled,
		UseAllFiles:   ctx.UseAllFiles,
		Compiler:      ctx.Compiler,
		BuildTags:     ctx.BuildTags,
		ReleaseTags:   ctx.ReleaseTags,
		InstallSuffix: ctx.InstallSuffix,
	}
}

func unpack_build_context(ctx *go_build_context) build.Context {
	return build.Context{
		GOARCH:        ctx.GOARCH,
		GOOS:          ctx.GOOS,
		GOROOT:        ctx.GOROOT,
		GOPATH:        ctx.GOPATH,
		CgoEnabled:    ctx.CgoEnabled,
		UseAllFiles:   ctx.UseAllFiles,
		Compiler:      ctx.Compiler,
		BuildTags:     ctx.BuildTags,
		ReleaseTags:   ctx.ReleaseTags,
		InstallSuffix: ctx.InstallSuffix,
	}
}
