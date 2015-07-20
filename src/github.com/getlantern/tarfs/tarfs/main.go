// This program generates a go file that embeds resources from a given path
// as a tar archive in a byte array. This can be passed to
// github.com/getlantern/tarfs.New() to create an in-memory filesystem from the
// embedded resources.
package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/getlantern/tarfs"
)

const (
	ExitWrongUsage      = 1
	ExitUnexpectedError = 2
)

var (
	pkg     = flag.String("pkg", "", "The package name to use")
	varname = flag.String("var", "Resources", "The variable name to use, defaults to 'Resources'")
)

func die(msg string, args ...interface{}) {
	fmt.Fprintf(os.Stderr, msg+"\n", args...)
	os.Exit(ExitUnexpectedError)
}

func main() {
	flag.Parse()
	if *pkg == "" {
		fmt.Fprintln(os.Stderr, "Please specify a pkg")
		flag.Usage()
		os.Exit(ExitWrongUsage)
	}
	if len(flag.Args()) == 0 {
		die("Please specify a folder to embed")
	}

	_, err := fmt.Fprintf(os.Stdout, "package %v\n\nvar %v = []byte(\"", *pkg, *varname)
	if err != nil {
		die("Unable to write file header: %v", err)
	}

	dir := flag.Arg(0)
	err = tarfs.EncodeToTarString(dir, os.Stdout)
	if err != nil {
		die("Unable to encode %v to tar string: %v", dir, err)
	}

	_, err = fmt.Fprintf(os.Stdout, `")`)
	if err != nil {
		die("Unable to write file footer: %v", err)
	}
}
