/*
Package update allows a program to "self-update", replacing its executable file
with new bytes.

Package update provides the facility to create user experiences like auto-updating
or user-approved updates which manifest as user prompts in commercial applications
with copy similar to "Restart to being using the new version of X".

Updating your program to a new version is as easy as:

	err := update.FromUrl("http://release.example.com/2.0/myprogram")
	if err != nil {
		fmt.Printf("Update failed: %v", err)
	}

The most low-level API is FromStream() which updates the current executable
with the bytes read from an io.Reader.

Additional APIs are provided for common update strategies which include
updating from a file with FromFile() and updating from the internet with
FromUrl().

Using the more advaced Download.UpdateFromUrl() API gives you the ability
to resume an interrupted download to enable large updates to complete even
over intermittent or slow connections. This API also enables more fine-grained
control over how the update is downloaded from the internet as well as access to
download progress,
*/
package update

import (
	"compress/gzip"
	"fmt"
	execpath "github.com/inconshreveable/go-execpath"
	"io"
	"io/ioutil"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
)

type MeteredReader struct {
	rd        io.ReadCloser
	totalSize int64
	progress  chan int
	totalRead int64
	ticks     int64
}

func (m *MeteredReader) Close() error {
	return m.rd.Close()
}

func (m *MeteredReader) Read(b []byte) (n int, err error) {
	chunkSize := (m.totalSize / 100) + 1
	lenB := int64(len(b))

	var nChunk int
	for start := int64(0); start < lenB; start += int64(nChunk) {
		end := start + chunkSize
		if end > lenB {
			end = lenB
		}

		nChunk, err = m.rd.Read(b[start:end])

		n += nChunk
		m.totalRead += int64(nChunk)

		if m.totalRead > (m.ticks * chunkSize) {
			m.ticks += 1
			// try to send on channel, but don't block if it's full
			select {
			case m.progress <- int(m.ticks + 1):
			default:
			}

			// give the progress channel consumer a chance to run
			runtime.Gosched()
		}

		if err != nil {
			return
		}
	}

	return
}

// We wrap the round tripper when making requests
// because we need to add headers to the requests we make
// even when they are requests made after a redirect
type RoundTripper struct {
	RoundTripFn func(*http.Request) (*http.Response, error)
}

func (rt *RoundTripper) RoundTrip(r *http.Request) (*http.Response, error) {
	return rt.RoundTripFn(r)
}

// Type Download encapsulates the necessary parameters and state
// needed to download an update from the internet. Create an instance
// with the NewDownload() factory function.
//
// You may only use a Download once,
type Download struct {
	// net/http.Client to use when downloading the update.
	// If nil, a default http.Client is used
	HttpClient *http.Client

	// Path on the file system to dowload the update to
	// If empty, a temporary file is used.
	// After the download begins, this path will be set
	// so that the client can use it to resume aborted
	// downloads
	Path string

	// Progress returns the percentage of the download
	// completed as an integer between 0 and 100
	Progress chan (int)

	// HTTP Method to use in the download request. Default is "GET"
	Method string

	// Set to true when the server confirms a new version is available
	// even if the updating process encounters an error later on
	Available bool
}

// NewDownload initializes a new Download object
func NewDownload() *Download {
	return &Download{
		HttpClient: new(http.Client),
		Progress:   make(chan int),
		Method:     "GET",
	}
}

// UpdateFromUrl downloads the given url from the internet to a file on disk
// and then calls FromStream() to update the current program's executable file
// with the contents of that file.
//
// If the update is successful, the downloaded file will be erased from disk.
// Otherwise, it will remain in d.Path to allow the download to resume later
// or be skipped entirely.
//
// Only HTTP/1.1 servers that implement the Range header are supported.
//
// UpdateFromUrl() uses HTTP status codes to determine what action to take.
//
// - The HTTP server should return 200 or 206 for the update to be downloaded.
//
// - The HTTP server should return 204 if no update is available at this time.
//
// - If the HTTP server returns a 3XX redirect, it will be followed
// according to d.HttpClient's redirect policy.
//
// - Any other HTTP status code will cause UpdateFromUrl to return an error.
func (d *Download) UpdateFromUrl(url string) (err error) {
	var offset int64 = 0
	var fp *os.File

	// Close the progress channel whenever this function completes
	defer close(d.Progress)

	// open a file where we will stream the downloaded update to
	// we do this first because if the caller specified a non-empty dlpath
	// we need to determine how large it is in order to resume the download
	if d.Path == "" {
		// no dlpath specified, use a random tempfile
		fp, err = ioutil.TempFile("", "update")
		if err != nil {
			return
		}
		defer fp.Close()

		// remember the path
		d.Path = fp.Name()
	} else {
		fp, err = os.OpenFile(d.Path, os.O_CREATE|os.O_RDWR|os.O_APPEND, 0600)
		if err != nil {
			return
		}
		defer fp.Close()

		// determine the file size so we can resume the download, if possible
		var fi os.FileInfo
		fi, err = fp.Stat()
		if err != nil {
			return
		}

		offset = fi.Size()
	}

	// create the download request
	req, err := http.NewRequest(d.Method, url, nil)
	if err != nil {
		return
	}

	// we have to add headers like this so they get used across redirects
	trans := d.HttpClient.Transport
	if trans == nil {
		trans = http.DefaultTransport
	}

	d.HttpClient.Transport = &RoundTripper{
		RoundTripFn: func(r *http.Request) (*http.Response, error) {
			// add header for download continuation
			if offset > 0 {
				r.Header.Add("Range", fmt.Sprintf("%d-", offset))
			}

			// ask for gzipped content so that net/http won't unzip it for us
			// and destroy the content length header we need for progress calculations
			r.Header.Add("Accept-Encoding", "gzip")

			return trans.RoundTrip(r)
		},
	}

	// start downloading the file
	resp, err := d.HttpClient.Do(req)
	if err != nil {
		return
	}
	defer resp.Body.Close()

	switch resp.StatusCode {
	// ok
	case 200, 206:
		d.Available = true

	// no update available
	case 204:
		err = fmt.Errorf("204 server response indicates no available update")
		return

	// server error
	default:
		err = fmt.Errorf("Non 2XX response when downloading update: %s", resp.Status)
		return
	}

	// Determine how much we have to download
	// net/http sets this to -1 when it is unknown
	clength := resp.ContentLength

	// Read the content from the response body
	rd := resp.Body

	// meter the rate at which we download content for
	// progress reporting if we know how much to expect
	if clength > 0 {
		rd = &MeteredReader{rd: rd, totalSize: clength, progress: d.Progress}
	}

	// Decompress the content if necessary
	if resp.Header.Get("Content-Encoding") == "gzip" {
		rd, err = gzip.NewReader(rd)
		if err != nil {
			return
		}
	}

	// Download the update
	_, err = io.Copy(fp, rd)
	if err != nil {
		return
	}

	// Seek to the beginning of the file before we pass fp to FromStream()
	_, err = fp.Seek(0, os.SEEK_SET)
	if err != nil {
		return
	}

	// Perform the update
	err = FromStream(fp)
	if err != nil {
		return
	}

	// remove the downloaded binary after it's been installed
	os.Remove(d.Path)

	return
}

// FromUrl downloads the contents of the given url and uses them to update
// the current program's executable file. It is a convenience function which is equivalent to
//
// 	NewDownload().UpdateFromUrl(url)
//
// See Download.UpdateFromUrl for more details.
func FromUrl(url string) error {
	return NewDownload().UpdateFromUrl(url)
}

// FromFile reads the contents of the given file and uses them
// to update the current program's executable file by calling FromStream().
func FromFile(filepath string) (err error) {
	// open the new binary
	fp, err := os.Open(filepath)
	if err != nil {
		return
	}
	defer fp.Close()

	// do the update
	err = FromStream(fp)
	return
}

// FromStream reads the contents of the supplied io.Reader newBinary
// and uses them to update the current program's executable file.
//
// FromStream performs the following actions to ensure a cross-platform safe
// update:
//
// - Creates a new file, /path/to/.program-name.new with mode 0755 and copies
// the contents of newBinary into the file
//
// - Renames the current program's executable file from /path/to/program-name
// to /path/to/.program-name.old
//
// - Renames /path/to/.program-name.new to /path/to/program-name
//
// - If the rename is successful, it erases /path/to/.program.old. If this operation
// fails, no error is reported.
//
// - If the rename is unsuccessful, it attempts to rename /path/to/.program-name.old
// back to /path/to/program-name. If this operation fails, the error is not reported
// in order to not mask the error that caused the rename recovery attempt.
func FromStream(newBinary io.Reader) (err error) {
	// get the path to the executable
	thisExecPath, err := execpath.Get()
	if err != nil {
		return
	}

	// get the directory the executable exists in
	execDir := filepath.Dir(thisExecPath)
	execName := filepath.Base(thisExecPath)

	// Copy the contents of of newbinary to a the new executable file
	newExecPath := filepath.Join(execDir, fmt.Sprintf(".%s.new", execName))
	fp, err := os.OpenFile(newExecPath, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0755)
	if err != nil {
		return
	}
	defer fp.Close()
	_, err = io.Copy(fp, newBinary)

	// if we don't call fp.Close(), windows won't let us move the new executable
	// because the file will still be "in use"
	fp.Close()

	// move the existing executable to a new file in the same directory
	oldExecPath := filepath.Join(execDir, fmt.Sprintf(".%s.old", execName))
	err = os.Rename(thisExecPath, oldExecPath)
	if err != nil {
		return
	}

	// move the new exectuable in to become the new program
	err = os.Rename(newExecPath, thisExecPath)

	if err != nil {
		// copy unsuccessful
		_ = os.Rename(oldExecPath, thisExecPath)
	} else {
		// copy successful, remove the old binary
		_ = os.Remove(oldExecPath)
	}

	return
}
