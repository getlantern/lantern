package main

import (
	"encoding/binary"
	"flag"
	"fmt"
	"io"
	"os"
	"reflect"
	"regexp"
	"strings"

	"github.com/akavel/rsrc/binutil"
	"github.com/akavel/rsrc/coff"
	"github.com/akavel/rsrc/ico"
)

const (
	RT_ICON       = coff.RT_ICON
	RT_GROUP_ICON = coff.RT_GROUP_ICON
	RT_MANIFEST   = coff.RT_MANIFEST
)

// on storing icons, see: http://blogs.msdn.com/b/oldnewthing/archive/2012/07/20/10331787.aspx
type GRPICONDIR struct {
	ico.ICONDIR
	Entries []GRPICONDIRENTRY
}

func (group GRPICONDIR) Size() int64 {
	return int64(binary.Size(group.ICONDIR) + len(group.Entries)*binary.Size(group.Entries[0]))
}

type GRPICONDIRENTRY struct {
	ico.IconDirEntryCommon
	Id uint16
}

var usage = `USAGE:

%s [-manifest FILE.exe.manifest] [-ico FILE.ico[,FILE2.ico...]] -o FILE.syso
  Generates a .syso file with specified resources embedded in .rsrc section,
  aimed for consumption by Go linker when building Win32 excecutables.

The generated *.syso files should get automatically recognized by 'go build'
command and linked into an executable/library, as long as there are any *.go
files in the same directory.

OPTIONS:
`

func main() {
	//TODO: allow in options advanced specification of multiple resources, as a tree (json?)
	//FIXME: verify that data file size doesn't exceed uint32 max value
	var fnamein, fnameico, fnamedata, fnameout, arch string
	flags := flag.NewFlagSet("", flag.ContinueOnError)
	flags.StringVar(&fnamein, "manifest", "", "path to a Windows manifest file to embed")
	flags.StringVar(&fnameico, "ico", "", "comma-separated list of paths to .ico files to embed")
	flags.StringVar(&fnamedata, "data", "", "path to raw data file to embed [WARNING: useless for Go 1.4+]")
	flags.StringVar(&fnameout, "o", "rsrc.syso", "name of output COFF (.res or .syso) file")
	flags.StringVar(&arch, "arch", "386", "architecture of output file - one of: 386, [EXPERIMENTAL: amd64]")
	_ = flags.Parse(os.Args[1:])
	if fnameout == "" || (fnamein == "" && fnamedata == "" && fnameico == "") {
		fmt.Fprintf(os.Stderr, usage, os.Args[0])
		flags.PrintDefaults()
		os.Exit(1)
	}

	var err error
	switch {
	case fnamein != "" || fnameico != "":
		err = run(fnamein, fnameico, fnameout, arch)
	case fnamedata != "":
		err = rundata(fnamedata, fnameout, arch)
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func rundata(fnamedata, fnameout, arch string) error {
	if !strings.HasSuffix(fnameout, ".syso") {
		return fmt.Errorf("Output file name '%s' must end with '.syso'", fnameout)
	}
	symname := strings.TrimSuffix(fnameout, ".syso")
	ok, err := regexp.MatchString(`^[a-z0-9_]+$`, symname)
	if err != nil {
		return fmt.Errorf("Internal error: %s", err)
	}
	if !ok {
		return fmt.Errorf("Output file name '%s' must be composed of only lowercase letters (a-z), digits (0-9) and underscore (_)", fnameout)
	}

	dat, err := binutil.SizedOpen(fnamedata)
	if err != nil {
		return fmt.Errorf("Error opening data file '%s': %s", fnamedata, err)
	}
	defer dat.Close()

	coff := coff.NewRDATA()
	err = coff.Arch(arch)
	if err != nil {
		return err
	}
	coff.AddData("_brsrc_"+symname, dat)
	coff.AddData("_ersrc_"+symname, io.NewSectionReader(strings.NewReader("\000\000"), 0, 2)) // TODO: why? copied from as-generated
	coff.Freeze()
	err = write(coff, fnameout)
	if err != nil {
		return err
	}

	//FIXME: output a .c file
	fmt.Println(strings.Replace(`#include "runtime.h"
extern byte _brsrc_NAME[], _ersrc_NAME;

/* func get_NAME() []byte */
void ·get_NAME(Slice a) {
  a.array = _brsrc_NAME;
  a.len = a.cap = &_ersrc_NAME - _brsrc_NAME;
  FLUSH(&a);
}`, "NAME", symname, -1))

	return nil
}

func run(fnamein, fnameico, fnameout, arch string) error {
	newid := make(chan uint16)
	go func() {
		for i := uint16(1); ; i++ {
			newid <- i
		}
	}()

	coff := coff.NewRSRC()
	err := coff.Arch(arch)
	if err != nil {
		return err
	}

	if fnamein != "" {
		manifest, err := binutil.SizedOpen(fnamein)
		if err != nil {
			return fmt.Errorf("Error opening manifest file '%s': %s", fnamein, err)
		}
		defer manifest.Close()

		id := <-newid
		coff.AddResource(RT_MANIFEST, id, manifest)
		fmt.Println("Manifest ID: ", id)
	}
	if fnameico != "" {
		for _, fnameicosingle := range strings.Split(fnameico, ",") {
			err := addicon(coff, fnameicosingle, newid)
			if err != nil {
				return err
			}
		}
	}

	coff.Freeze()

	return write(coff, fnameout)
}

func addicon(coff *coff.Coff, fname string, newid <-chan uint16) error {
	f, err := os.Open(fname)
	if err != nil {
		return err
	}
	//defer f.Close() don't defer, files will be closed by OS when app closes

	icons, err := ico.DecodeHeaders(f)
	if err != nil {
		return err
	}

	if len(icons) > 0 {
		// RT_ICONs
		group := GRPICONDIR{ICONDIR: ico.ICONDIR{
			Reserved: 0, // magic num.
			Type:     1, // magic num.
			Count:    uint16(len(icons)),
		}}
		for _, icon := range icons {
			id := <-newid
			r := io.NewSectionReader(f, int64(icon.ImageOffset), int64(icon.BytesInRes))
			coff.AddResource(RT_ICON, id, r)
			group.Entries = append(group.Entries, GRPICONDIRENTRY{icon.IconDirEntryCommon, id})
		}
		id := <-newid
		coff.AddResource(RT_GROUP_ICON, id, group)
		fmt.Println("Icon ", fname, " ID: ", id)
	}

	return nil
}

func write(coff *coff.Coff, fnameout string) error {
	out, err := os.Create(fnameout)
	if err != nil {
		return err
	}
	defer out.Close()
	w := binutil.Writer{W: out}

	// write the resulting file to disk
	binutil.Walk(coff, func(v reflect.Value, path string) error {
		if binutil.Plain(v.Kind()) {
			w.WriteLE(v.Interface())
			return nil
		}
		vv, ok := v.Interface().(binutil.SizedReader)
		if ok {
			w.WriteFromSized(vv)
			return binutil.WALK_SKIP
		}
		return nil
	})

	if w.Err != nil {
		return fmt.Errorf("Error writing output file: %s", w.Err)
	}

	return nil
}
