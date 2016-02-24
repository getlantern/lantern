// Copyright 2015 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package binres

import (
	"bytes"
	"encoding"
	"encoding/xml"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"math"
	"os"
	"path"
	"sort"
	"strings"
	"testing"
)

func printrecurse(t *testing.T, pl *Pool, el *Element, ws string) {
	for _, attr := range el.attrs {
		ns := ""
		if attr.NS != math.MaxUint32 {
			ns = pl.strings[int(attr.NS)]
			nss := strings.Split(ns, "/")
			ns = nss[len(nss)-1]
		}

		val := ""
		if attr.RawValue != math.MaxUint32 {
			val = pl.strings[int(attr.RawValue)]
		} else {
			switch attr.TypedValue.Type {
			case DataIntDec:
				val = fmt.Sprintf("%v", attr.TypedValue.Value)
			case DataIntBool:
				val = fmt.Sprintf("%v", attr.TypedValue.Value == 1)
			default:
				val = fmt.Sprintf("0x%08X", attr.TypedValue.Value)
			}
		}
		dt := attr.TypedValue.Type

		t.Logf("%s|attr:ns(%v) name(%s) val(%s) valtyp(%s)\n", ws, ns, pl.strings[int(attr.Name)], val, dt)
	}
	t.Log()
	for _, e := range el.Children {
		printrecurse(t, pl, e, ws+"        ")
	}
}

func TestBootstrap(t *testing.T) {
	bin, err := ioutil.ReadFile("testdata/bootstrap.bin")
	if err != nil {
		log.Fatal(err)
	}

	checkMarshal := func(res encoding.BinaryMarshaler, bsize int) {
		b, err := res.MarshalBinary()
		if err != nil {
			t.Error(err)
		}
		idx := debugIndices[res]
		a := bin[idx : idx+bsize]
		if !bytes.Equal(a, b) {
			x, y := len(a), len(b)
			if x != y {
				t.Errorf("%v: %T: byte length does not match, have %v, want %v", idx, res, y, x)
			}
			if x > y {
				x, y = y, x
			}
			mismatch := false
			for i := 0; i < x; i++ {
				if mismatch = a[i] != b[i]; mismatch {
					t.Errorf("%v: %T: first byte mismatch at %v of %v", idx, res, i, bsize)
					break
				}
			}
			if mismatch {
				// print out a reasonable amount of data to help identify issues
				truncate := x > 1300
				if truncate {
					x = 1300
				}
				t.Log("      HAVE               WANT")
				for i := 0; i < x; i += 4 {
					he, we := 4, 4
					if i+he >= x {
						he = x - i
					}
					if i+we >= y {
						we = y - i
					}
					t.Logf("%3v | % X        % X\n", i, b[i:i+he], a[i:i+we])
				}
				if truncate {
					t.Log("... output truncated.")
				}
			}
		}
	}

	bxml := new(XML)
	if err := bxml.UnmarshalBinary(bin); err != nil {
		t.Fatal(err)
	}

	for i, x := range bxml.Pool.strings {
		t.Logf("Pool(%v): %q\n", i, x)
	}

	for _, e := range bxml.Children {
		printrecurse(t, bxml.Pool, e, "")
	}

	checkMarshal(&bxml.chunkHeader, int(bxml.headerByteSize))
	checkMarshal(bxml.Pool, bxml.Pool.size())
	checkMarshal(bxml.Map, bxml.Map.size())
	checkMarshal(bxml.Namespace, bxml.Namespace.size())

	for el := range bxml.iterElements() {
		checkMarshal(el, el.size())
		checkMarshal(el.end, el.end.size())
	}

	checkMarshal(bxml.Namespace.end, bxml.Namespace.end.size())
	checkMarshal(bxml, bxml.size())
}

func retset(xs []string) []string {
	m := make(map[string]struct{})
	fo := xs[:0]
	for _, x := range xs {
		if x == "" {
			continue
		}
		if _, ok := m[x]; !ok {
			m[x] = struct{}{}
			fo = append(fo, x)
		}
	}
	return fo
}

type byNamespace []xml.Attr

func (a byNamespace) Len() int      { return len(a) }
func (a byNamespace) Swap(i, j int) { a[i], a[j] = a[j], a[i] }
func (a byNamespace) Less(i, j int) bool {
	if a[j].Name.Space == "" {
		return a[i].Name.Space != ""
	}
	return false
}

// WIP approximation of first steps to be taken to encode manifest
func TestEncode(t *testing.T) {
	f, err := os.Open("testdata/bootstrap.xml")
	if err != nil {
		t.Fatal(err)
	}

	var attrs []xml.Attr

	dec := xml.NewDecoder(f)
	for {
		tkn, err := dec.Token()
		if err != nil {
			if err == io.EOF {
				break
			}
			return
			// t.Fatal(err)
		}
		tkn = xml.CopyToken(tkn)

		switch tkn := tkn.(type) {
		case xml.StartElement:
			attrs = append(attrs, tkn.Attr...)
		default:
			// t.Error("unhandled token type", tkn)
		}
	}

	bvc := xml.Attr{
		Name: xml.Name{
			Space: "",
			Local: "platformBuildVersionCode",
		},
		Value: "15",
	}
	bvn := xml.Attr{
		Name: xml.Name{
			Space: "",
			Local: "platformBuildVersionName",
		},
		Value: "4.0.3",
	}
	attrs = append(attrs, bvc, bvn)

	sort.Sort(byNamespace(attrs))
	var names, vals []string
	for _, attr := range attrs {
		if strings.HasSuffix(attr.Name.Space, "tools") {
			continue
		}
		names = append(names, attr.Name.Local)
		vals = append(vals, attr.Value)
	}

	var all []string
	all = append(all, names...)
	all = append(all, vals...)

	// do not eliminate duplicates until the entire slice has been composed.
	// consider <activity android:label="label" .../>
	// all attribute names come first followed by values; in such a case, the value "label"
	// would be a reference to the same "android:label" in the string pool which will occur
	// within the beginning of the pool where other attr names are located.
	pl := new(Pool)
	for _, x := range retset(all) {
		pl.strings = append(pl.strings, x)
		// t.Logf("Pool(%v) %q\n", i, x)
	}
}

func TestOpenTable(t *testing.T) {
	sdkdir := os.Getenv("ANDROID_HOME")
	if sdkdir == "" {
		t.Skip("ANDROID_HOME env var not set")
	}
	tbl, err := OpenTable(path.Join(sdkdir, "platforms/android-15/android.jar"))
	if err != nil {
		t.Fatal(err)
	}
	if len(tbl.pkgs) == 0 {
		t.Fatal("failed to decode any resource packages")
	}

	pkg := tbl.pkgs[0]

	t.Log("package name:", pkg.name)

	for i, x := range pkg.typePool.strings {
		t.Logf("typePool[i=%v]: %s\n", i, x)
	}

	for i, spec := range pkg.specs {
		t.Logf("spec[i=%v]: %v %q\n", i, spec.id, pkg.typePool.strings[spec.id-1])
		for j, typ := range spec.types {
			t.Logf("\ttype[i=%v]: %v\n", j, typ.id)
			for k, nt := range typ.entries {
				if nt == nil { // NoEntry
					continue
				}
				t.Logf("\t\tentry[i=%v]: %v %q\n", k, nt.key, pkg.keyPool.strings[nt.key])
				if k > 5 {
					t.Logf("\t\t... truncating output")
					break
				}
			}
		}
	}
}

func TestTableRefByName(t *testing.T) {
	sdkdir := os.Getenv("ANDROID_HOME")
	if sdkdir == "" {
		t.Skip("ANDROID_HOME env var not set")
	}
	tbl, err := OpenTable(path.Join(sdkdir, "platforms/android-15/android.jar"))
	if err != nil {
		t.Fatal(err)
	}
	if len(tbl.pkgs) == 0 {
		t.Fatal("failed to decode any resource packages")
	}

	ref, err := tbl.RefByName("@android:style/Theme.NoTitleBar.Fullscreen")
	if err != nil {
		t.Fatal(err)
	}

	if want := uint32(0x01030007); uint32(ref) != want {
		t.Fatalf("RefByName does not match expected result, have %0#8x, want %0#8x", ref, want)
	}
}
