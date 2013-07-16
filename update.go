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
	"fmt"
	execpath "github.com/inconshreveable/go-execpath"
	"io"
	"io/ioutil"
	"net/http"
	"os"
	"path"
	"strconv"
)

var (
	// Returned when the remote server indicates that no download is available
	UpdateUnavailable error
)

func init() {
	UpdateUnavailable = fmt.Errorf("204 server response indicates no available update")
}

// Type Download encapsulates the necessary parameters and state
// needed to download an update from the internet. Create an instance
// with the NewDownload() factory function.
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
	Progress chan(int)

	// HTTP Method to use in the download request. Default is "GET"
	Method string
}

// NewDownload initializes a new Download object
func NewDownload() *Download {
	return &Download{
		HttpClient: new(http.Client),
		Progress: make(chan int, 100),
		Method: "GET",
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
// This will cause UpdateFromUrl to return the error UpdateUnavailable.
//
// - If the HTTP server returns a 3XX redirect, it will be followed
// according to d.HttpClient's redirect policy.
//
// - Any other HTTP status code will cause UpdateFromUrl to return an error.
func (d *Download) UpdateFromUrl(url string) (err error) {
	var offset int64 = 0
	var fp *os.File

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

	// add header for download continuation
	if offset > 0 {
		req.Header.Add("Range", fmt.Sprintf("%d-", offset))
	}

	// start downloading the file
	resp, err := d.HttpClient.Do(req)
	if err != nil {
		return
	}
	defer resp.Body.Close()

	switch resp.StatusCode {
	// ok
	case 200:
	case 206:

	// no update available
	case 204:
		err = UpdateUnavailable
		return

	// server error
	default:
		err = fmt.Errorf("Non 2XX response when downloading update: %s", resp.Status)
		return
	}

	// Determine how much we have to download
	clength := 0
	if resp.Header["Content-Length"] != nil {
		clength, err = strconv.Atoi(resp.Header["Content-Length"][0])
		if err != nil {
			clength = 0
		}
	}

	// Download the update
	defer close(d.Progress)
	if clength > 0 {
		nTotal := int64(0)
		for i := 0; i < 100; i++ {
			var n int64
			nCopy := int64(clength / 100) + 1
			n, err = io.CopyN(fp, resp.Body, nCopy)
			nTotal += n
			d.Progress <- (i+1)

			if err == io.EOF {
				break
			} else if err != nil {
				return
			}
		}

		// make sure we downloaded the entire file
		if nTotal != int64(clength) {
			err = fmt.Errorf("Failed to download entire file, only %d bytes out of %d", nTotal, clength)
			return
		}
	} else {
		// streaming response, we can't calculate progress, just copy it all
		_, err = io.Copy(fp, resp.Body)
		if err != nil {
			return
		}
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
// - Renames the current program's executable file from /path/to/program-name
// to /path/to/.program-name.old
//
// - Opens the now-empty path /path/to/program-name with mode 0755 and copies
// the contents of newBinary into the file.
//
// - If the copy is successful, it erases /path/to/.program.old. If this operation
// fails, no error is reported.
//
// - If the copy is unsuccessful, it attempts to rename /path/to/.program-name.old
// back to /path/to/program-name. If this operation fails, the error is not reported
// in order to not mask the error that caused the rename recovery attempt.
func FromStream(newBinary io.Reader) (err error) {
	// get the path to the executable
	thisExecPath, err := execpath.Get()
	if err != nil {
		return
	}

	// get the directory the executable exists in
	execDir := path.Dir(thisExecPath)
	execName := path.Base(thisExecPath)

	// move the existing executable to a new file in the same directory
	oldExecPath := path.Join(execDir, fmt.Sprintf(".%s.old", execName))
	err = os.Rename(thisExecPath, oldExecPath)
	if err != nil {
		return
	}

	fp, err := os.OpenFile(thisExecPath, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0755)
	if err != nil {
		return
	}
	defer fp.Close()

	_, err = io.Copy(fp, newBinary)

	if err != nil {
		// copy unsuccessful
		_ = os.Rename(oldExecPath, thisExecPath)
	} else {
		// copy successful, remove the old binary
		_ = os.Remove(oldExecPath)
	}

	return
}
