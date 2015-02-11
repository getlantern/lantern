package main

import (
	"archive/tar"
	"encoding/hex"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

var (
	pkg     = flag.String("pkg", "main", "The package name to use, defaults to 'main'")
	varname = flag.String("var", "Data", "The variable name to use, defaults to 'Data'")
)

func main() {
	flag.Parse()
	if len(flag.Args()) == 0 {
		fmt.Fprintf(os.Stderr, "Please specify a folder to tar\n")
		os.Exit(1)
	}
	folder := flag.Arg(0)
	folderPrefix := folder + "/"
	folderPrefixLen := len(folderPrefix)

	fmt.Fprintf(os.Stdout, "package %v\n\nvar %v = []byte(\"", *pkg, *varname)

	tw := tar.NewWriter(&stringencodingwriter{os.Stdout})
	defer func() {
		err := tw.Close()
		if err != nil {
			fmt.Fprintf(os.Stderr, "Unable to close tar writer: %v\n", err)
			os.Exit(3)
		}

		// Close the quote
		fmt.Fprintf(os.Stdout, `")`)
	}()

	err := filepath.Walk(folder, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return fmt.Errorf("Unable to walk to %v: %v", path, err)
		}
		if info.IsDir() {
			return nil
		}
		name := path
		if strings.HasPrefix(name, folderPrefix) {
			name = path[folderPrefixLen:]
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
		fmt.Fprintln(os.Stderr, err.Error())
		os.Exit(2)
	}
}

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
