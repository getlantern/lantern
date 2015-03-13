package tarfs

import (
	"archive/tar"
	"bytes"
	"errors"
	"fmt"
	"io"
	"io/ioutil"
	"math"
	"net/http"
	"os"
	"path"
	"path/filepath"
	"strings"
	"time"

	"github.com/getlantern/golog"
)

const (
	ExitLocalDirUnavailable = 1
)

var (
	log            = golog.LoggerFor("tarfs")
	fileTimestamp  = time.Now()
	emptyFileInfos = []os.FileInfo{}
)

// FileSystem is a tarfs filesystem. It exposes a Get method for accessing
// resources by path. It also implements http.FileSystem for use with
// http.FileServer.
type FileSystem struct {
	files map[string][]byte
	local string
}

// New creates a new FileSystem using the given in-memory tar data. If local is
// a non-empty string, the resulting FileSystem will first look for resources in
// the local file system before returning an embedded resource.
func New(tarData []byte, local string) (*FileSystem, error) {
	if local != "" {
		_, err := os.Stat(local)
		if err != nil {
			if os.IsNotExist(err) {
				log.Debugf("Local dir %v does not exist, not using\n", local)
			} else {
				log.Errorf("Unable to stat local dir %v, not using: %v\n", local, err)
			}
			local = ""
		} else {
			log.Tracef("Using local filesystem at %v", local)
		}
	}

	fs := &FileSystem{make(map[string][]byte, 0), local}

	// Read the tar data and index it into a map
	br := &trackingreader{bytes.NewReader(tarData), 0}
	for {
		// We construct a new tar reader every time because each loop advances
		// the underlying trackingreader to the next tar header and the existing
		// tar reader doesn't know it.
		tr := tar.NewReader(br)

		hdr, err := tr.Next()
		if err == io.EOF {
			log.Trace("Reached end of tar archive")
			break
		}
		if err != nil {
			return nil, fmt.Errorf("Unable to read next tar header: %v", err)
		}

		// Create a slice to the tar data started after the header and
		// containing the specified size of data. We don't use tr.Read() so that
		// we can avoid copying.
		end := br.pos + hdr.Size
		fs.files[hdr.Name] = tarData[br.pos:end]

		// Advance to the next tar header. Note that we round up to the next
		// multiple of 512 because tar files contain 512 byte blocks that are 0
		// padded if the actual data doesn't align with the 512 byte boundaries.
		err = br.AdvanceTo(int64(math.Ceil(float64(end)/512)) * 512)
		if err != nil {
			return nil, fmt.Errorf("Unable to seek to next header: %v", err)
		}
	}

	return fs, nil
}

// SubDir returns a FileSystem corresponding to the given directory in the
// original FileSystem.
func (fs *FileSystem) SubDir(dir string) *FileSystem {
	newLocal := ""
	if fs.local != "" {
		newLocal = filepath.Join(fs.local, dir)
	}
	newFiles := make(map[string][]byte)
	for p, b := range fs.files {
		if filepath.HasPrefix(p, dir) {
			k := p[len(dir)+1:]
			newFiles[k] = b
		}
	}
	return &FileSystem{
		files: newFiles,
		local: newLocal,
	}
}

// Get returns the bytes for the resource at the given path. If this FileSystem
// was configured with a local directory, and that local directory contains
// a file at the given path, Get will return the value from the local file.
// Otherwise, it returns the bytes from the embedded in-memory resource.
//
// Note - the implementation of local reads is not optimized and is primarily
// intended for development-time usage.
func (fs *FileSystem) Get(p string) ([]byte, error) {
	p = path.Clean(p)
	log.Tracef("Getting %v", p)
	if fs.local != "" {
		b, err := ioutil.ReadFile(filepath.Join(fs.local, p))
		if err != nil {
			if !os.IsNotExist(err) {
				log.Debugf("Error accessing resource %v on filesystem: %v", p, err)
				return nil, err
			}
			log.Tracef("Resource %v does not exist on filesystem, using embedded resource instead", p)
		} else {
			log.Tracef("Using local resource %v", p)
			return b, nil
		}
	}
	b, found := fs.files[p]
	if !found {
		err := fmt.Errorf("%v not found", p)
		return nil, err
	}
	log.Tracef("Using embedded resource %v", p)
	return b, nil
}

// Open implements the method from http.FileSystem. tarfs doesn't currently
// support directories, so any request for a name ending in / will return an
// empty directory.
func (fs *FileSystem) Open(name string) (http.File, error) {
	if strings.HasSuffix(name, "/") {
		log.Tracef("Returning empty directory for %v", name)
		return newAssetDirectory(name), nil
	}

	// Remove leading slash
	if len(name) > 0 && name[0] == '/' {
		name = name[1:]
	}

	b, err := fs.Get(name)
	if err != nil {
		return nil, err
	}
	return newAssetFile(name, b), nil
}

// trackingreader is a wrapper around bytes.Reader that tracks the current
// position.
type trackingreader struct {
	*bytes.Reader
	pos int64
}

// Read implements the method from io.Reader
func (r *trackingreader) Read(b []byte) (int, error) {
	n, err := r.Reader.Read(b)
	r.pos += int64(n)
	return n, err
}

// AdvanceTo advances the trackingreader to the given position (relative to the
// start of the stream)
func (r *trackingreader) AdvanceTo(to int64) error {
	n, err := r.Reader.Seek(to, 0)
	if err != nil {
		return err
	}
	r.pos = n
	return nil
}

/*******************************************************************************
 * Implementations of the http.File interface, cargo culted from
 * https://github.com/elazarl/go-bindata-assetfs and slightly modified.
 ******************************************************************************/

// FakeFile implements os.FileInfo interface for a given path and size
type FakeFile struct {
	// Path is the path of this file
	Path string
	// Dir marks of the path is a directory
	Dir bool
	// Len is the length of the fake file, zero if it is a directory
	Len int64
}

func (f *FakeFile) Name() string {
	_, name := path.Split(f.Path)
	return name
}

func (f *FakeFile) Mode() os.FileMode {
	mode := os.FileMode(0644)
	if f.Dir {
		return mode | os.ModeDir
	}
	return mode
}

func (f *FakeFile) ModTime() time.Time {
	return fileTimestamp
}

func (f *FakeFile) Size() int64 {
	return f.Len
}

func (f *FakeFile) IsDir() bool {
	return f.Mode().IsDir()
}

func (f *FakeFile) Sys() interface{} {
	return nil
}

// AssetFile implements http.File interface for a no-directory file with content
type AssetFile struct {
	*bytes.Reader
	io.Closer
	FakeFile
}

func newAssetFile(name string, content []byte) *AssetFile {
	return &AssetFile{
		bytes.NewReader(content),
		ioutil.NopCloser(nil),
		FakeFile{name, false, int64(len(content))}}
}

func (f *AssetFile) Readdir(count int) ([]os.FileInfo, error) {
	return nil, errors.New("not a directory")
}

func (f *AssetFile) Stat() (os.FileInfo, error) {
	return f, nil
}

// AssetDirectory implements http.File interface for a directory. It is always
// empty.
type AssetDirectory struct {
	AssetFile
}

func newAssetDirectory(name string) *AssetDirectory {
	return &AssetDirectory{
		AssetFile{
			bytes.NewReader(nil),
			ioutil.NopCloser(nil),
			FakeFile{name, true, 0},
		},
	}
}

func (f *AssetDirectory) Readdir(count int) ([]os.FileInfo, error) {
	return emptyFileInfos, nil
}

func (f *AssetDirectory) Stat() (os.FileInfo, error) {
	return f, nil
}
