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
	"path/filepath"
	"strings"
	"time"
)

var (
	fileTimestamp = time.Now()
)

type FileSystem struct {
	files map[string][]byte
	local http.FileSystem
}

func (fs *FileSystem) Get(name string) []byte {
	return fs.files[name]
}

func New(data []byte, local string) (*FileSystem, error) {
	var lfs http.FileSystem
	if local != "" {
		_, err := os.Stat(local)
		if err != nil {
			if os.IsNotExist(err) {
				fmt.Fprintf(os.Stderr, "Local dir %v does not exist, not using\n", local)
			} else {
				fmt.Fprintf(os.Stderr, "Unable to stat local dir %v: %v\n", local, err)
				os.Exit(5)
			}
		} else {
			lfs = http.Dir(local)
		}
	}
	fs := &FileSystem{make(map[string][]byte, 0), lfs}

	br := &trackingreader{bytes.NewReader(data), 0}

	for {
		tr := tar.NewReader(br)
		hdr, err := tr.Next()
		if err == io.EOF {
			// end of tar archive
			break
		}
		if err != nil {
			return nil, fmt.Errorf("Unable to read next tar header: %v", err)
		}

		// Set the data to be a slice of the original
		end := br.pos + hdr.Size
		fs.files[hdr.Name] = data[br.pos:end]
		// Round up to multiple of 512
		end = int64(math.Ceil(float64(end)/512)) * 512
		err = br.AdvanceTo(end)
		if err != nil {
			return nil, fmt.Errorf("Unable to seek to next header: %v", err)
		}
	}

	return fs, nil
}

func (fs *FileSystem) Open(name string) (http.File, error) {
	name = filepath.Clean(name)
	if strings.HasSuffix(name, "/") {
		fmt.Fprintf(os.Stderr, "Returning directory for %v", name)
		return NewAssetDirectory(name), nil
	}

	if len(name) > 0 && name[0] == '/' {
		name = name[1:]
	}

	fmt.Fprintf(os.Stderr, "name: %v\n", name)
	if fs.local != nil {
		// Use local filesystem when possible
		file, err := fs.local.Open(name)
		if err == nil {
			return file, err
		}
	}
	b, found := fs.files[name]
	if !found {
		return nil, fmt.Errorf("File %v not found", name)
	}
	fmt.Fprintf(os.Stderr, "Found: %v\n", name)
	return NewAssetFile(name, b), nil
}

type trackingreader struct {
	*bytes.Reader

	pos int64
}

func (r *trackingreader) Read(b []byte) (int, error) {
	n, err := r.Reader.Read(b)
	r.pos += int64(n)
	return n, err
}

func (r *trackingreader) AdvanceTo(to int64) error {
	n, err := r.Reader.Seek(to, 0)
	if err != nil {
		return err
	}
	r.pos = n
	return nil
}

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
	_, name := filepath.Split(f.Path)
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

func NewAssetFile(name string, content []byte) *AssetFile {
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

// AssetDirectory implements http.File interface for a directory
type AssetDirectory struct {
	AssetFile
	ChildrenRead int
	Children     []os.FileInfo
}

func NewAssetDirectory(name string) *AssetDirectory {
	fileinfos := make([]os.FileInfo, 0)
	return &AssetDirectory{
		AssetFile{
			bytes.NewReader(nil),
			ioutil.NopCloser(nil),
			FakeFile{name, true, 0},
		},
		0,
		fileinfos}
}

func (f *AssetDirectory) Readdir(count int) ([]os.FileInfo, error) {
	if count <= 0 {
		return f.Children, nil
	}
	if f.ChildrenRead+count > len(f.Children) {
		count = len(f.Children) - f.ChildrenRead
	}
	rv := f.Children[f.ChildrenRead : f.ChildrenRead+count]
	f.ChildrenRead += count
	return rv, nil
}

func (f *AssetDirectory) Stat() (os.FileInfo, error) {
	return f, nil
}
