package tarfs

import (
	"archive/tar"
	"encoding/hex"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

// EncodeToTarString takes the contents of the given directory and writes it to
// the given Writer in the form of an unquoted UTF-8 encoded string that
// contains a tar archive of the directory, for example
// \x69\x6e\x64\x65\x78\x2e\x68\x74 ...
func EncodeToTarString(dir string, w io.Writer) error {
	tw := tar.NewWriter(&stringencodingwriter{w})
	defer tw.Close()

	dirPrefix := dir + "/"
	dirPrefixLen := len(dirPrefix)

	err := filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return fmt.Errorf("Unable to walk to %v: %v", path, err)
		}
		if info.IsDir() {
			return nil
		}
		name := path
		if strings.HasPrefix(name, dirPrefix) {
			name = path[dirPrefixLen:]
		}
		hdr := &tar.Header{
			Name: name,
			Size: info.Size(),
		}
		err = tw.WriteHeader(hdr)
		if err != nil {
			return fmt.Errorf("Unable to write tar header: %v", err)
		}
		file, err := os.Open(path)
		if err != nil {
			return fmt.Errorf("Unable to open file %v: %v", path, err)
		}
		defer file.Close()
		_, err = io.Copy(tw, file)
		if err != nil {
			return fmt.Errorf("Unable to copy file %v to tar: %v", path, err)
		}
		return nil
	})

	if err != nil {
		return err
	}

	err = tw.Close()
	if err != nil {
		return fmt.Errorf("Unable to close tar writer: %v", err)
	}

	return nil
}

// stringencodingwriter is a writer that encodes written bytes into a UTF-8
// encoded string.
type stringencodingwriter struct {
	io.Writer
}

func (w *stringencodingwriter) Write(buf []byte) (int, error) {
	n := 0
	for _, b := range buf {
		_, err := fmt.Fprintf(w.Writer, `\x%v`, hex.EncodeToString([]byte{b}))
		if err != nil {
			return n, err
		}
		n += 1
	}
	return n, nil
}
