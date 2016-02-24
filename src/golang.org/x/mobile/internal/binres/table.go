// Copyright 2015 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package binres

import (
	"archive/zip"
	"bytes"
	"errors"
	"fmt"
	"io"
	"strings"
	"unicode/utf16"
)

const NoEntry = 0xFFFFFFFF

// TableRef uniquely identifies entries within a resource table.
type TableRef uint32

// Resolve returns the Entry of TableRef in the given table.
//
// A TableRef is structured as follows:
//  0xpptteeee
//  pp: package index
//  tt: type spec index in package
//  eeee: entry index in type spec
//
// The package and type spec values start at 1 for the first item,
// to help catch cases where they have not been supplied.
func (ref TableRef) Resolve(tbl *Table) (*Entry, error) {
	pkg := tbl.pkgs[uint8(ref>>24)-1]
	spec := pkg.specs[uint8(ref>>16)-1]
	idx := uint16(ref)

	for _, typ := range spec.types {
		if idx < uint16(len(typ.entries)) {
			nt := typ.entries[idx]
			if nt == nil {
				return nil, errors.New("nil entry match")
			}
			return nt, nil
		}
	}

	return nil, errors.New("failed to resolve table reference")
}

// Table is a container for packaged resources. Resource values within a package
// are obtained through pool while resource names and identifiers are obtained
// through each package's type and key pools respectively.
type Table struct {
	chunkHeader
	pool *Pool
	pkgs []*Package
}

// OpenTable decodes resources.arsc from an sdk platform jar.
func OpenTable(path string) (*Table, error) {
	zr, err := zip.OpenReader(path)
	if err != nil {
		return nil, err
	}
	defer zr.Close()

	buf := new(bytes.Buffer)
	for _, f := range zr.File {
		if f.Name == "resources.arsc" {
			rc, err := f.Open()
			if err != nil {
				return nil, err
			}
			_, err = io.Copy(buf, rc)
			if err != nil {
				return nil, err
			}
			rc.Close()
			break
		}
	}
	if buf.Len() == 0 {
		return nil, fmt.Errorf("failed to read resources.arsc")
	}

	tbl := new(Table)
	if err := tbl.UnmarshalBinary(buf.Bytes()); err != nil {
		return nil, err
	}
	return tbl, nil
}

// SpecByName parses the spec name from an entry string if necessary and returns
// the Package and TypeSpec associated with that name.
//
// For example:
//  tbl.SpecByName("@android:style/Theme.NoTitleBar")
//  tbl.SpecByName("style")
// Both locate the spec by name "style".
func (tbl *Table) SpecByName(name string) (int, *Package, int, *TypeSpec, error) {
	n := strings.TrimPrefix(name, "@android:")
	n = strings.Split(n, "/")[0]
	for pp, pkg := range tbl.pkgs {
		for tt, spec := range pkg.specs {
			if n == pkg.typePool.strings[spec.id-1] {
				return pp, pkg, tt, spec, nil
			}
		}
	}
	return 0, nil, 0, nil, fmt.Errorf("spec by name not found: %q", name)
}

// RefByName returns the TableRef by a given name. The ref may be used to resolve the
// associated Entry and is used for the generation of binary manifest files.
func (tbl *Table) RefByName(name string) (TableRef, error) {
	pp, pkg, tt, spec, err := tbl.SpecByName(name)
	if err != nil {
		return 0, err
	}

	q := strings.Split(name, "/")
	if len(q) != 2 {
		return 0, fmt.Errorf("invalid entry format, missing forward-slash: %q", name)
	}
	n := q[1]

	for _, t := range spec.types {
		for eeee, nt := range t.entries {
			if nt == nil { // NoEntry
				continue
			}
			if n == pkg.keyPool.strings[nt.key] {
				return TableRef(uint32(eeee) | uint32(tt+1)<<16 | uint32(pp+1)<<24), nil
			}
		}
	}
	return 0, fmt.Errorf("failed to find table ref by %q", name)
}

func (tbl *Table) UnmarshalBinary(bin []byte) error {
	if err := (&tbl.chunkHeader).UnmarshalBinary(bin); err != nil {
		return err
	}
	if tbl.typ != ResTable {
		return fmt.Errorf("unexpected resource type %s, want %s", tbl.typ, ResTable)
	}

	npkgs := btou32(bin[8:])
	tbl.pkgs = make([]*Package, npkgs)

	buf := bin[tbl.headerByteSize:]

	tbl.pool = new(Pool)
	if err := tbl.pool.UnmarshalBinary(buf); err != nil {
		return err
	}
	buf = buf[tbl.pool.size():]
	for i := range tbl.pkgs {
		pkg := new(Package)
		if err := pkg.UnmarshalBinary(buf); err != nil {
			return err
		}
		tbl.pkgs[i] = pkg
		buf = buf[pkg.byteSize:]
	}

	return nil
}

// Package contains a collection of resource data types.
type Package struct {
	chunkHeader

	id   uint32
	name string

	lastPublicType uint32 // last index into typePool that is for public use
	lastPublicKey  uint32 // last index into keyPool that is for public use

	typePool *Pool // type names; e.g. theme
	keyPool  *Pool // resource names; e.g. Theme.NoTitleBar

	specs []*TypeSpec
}

func (pkg *Package) UnmarshalBinary(bin []byte) error {
	if err := (&pkg.chunkHeader).UnmarshalBinary(bin); err != nil {
		return err
	}
	if pkg.typ != ResTablePackage {
		return errWrongType(pkg.typ, ResTablePackage)
	}

	pkg.id = btou32(bin[8:])

	var name []uint16
	for i := 0; i < 128; i++ {
		x := btou16(bin[12+i*2:])
		if x == 0 {
			break
		}
		name = append(name, x)
	}
	pkg.name = string(utf16.Decode(name))

	typeOffset := btou32(bin[268:]) // 0 if inheriting from another package
	pkg.lastPublicType = btou32(bin[272:])
	keyOffset := btou32(bin[276:]) // 0 if inheriting from another package
	pkg.lastPublicKey = btou32(bin[280:])

	var idOffset uint32 // value determined by either typePool or keyPool below

	if typeOffset != 0 {
		pkg.typePool = new(Pool)
		if err := pkg.typePool.UnmarshalBinary(bin[typeOffset:]); err != nil {
			return err
		}
		idOffset = typeOffset + pkg.typePool.byteSize
	}

	if keyOffset != 0 {
		pkg.keyPool = new(Pool)
		if err := pkg.keyPool.UnmarshalBinary(bin[keyOffset:]); err != nil {
			return err
		}
		idOffset = keyOffset + pkg.keyPool.byteSize
	}

	if idOffset == 0 {
		return nil
	}

	buf := bin[idOffset:]
	for len(pkg.specs) < len(pkg.typePool.strings) {
		t := ResType(btou16(buf))
		switch t {
		case ResTableTypeSpec:
			spec := new(TypeSpec)
			if err := spec.UnmarshalBinary(buf); err != nil {
				return err
			}
			pkg.specs = append(pkg.specs, spec)
			buf = buf[spec.byteSize:]
		case ResTableType:
			typ := new(Type)
			if err := typ.UnmarshalBinary(buf); err != nil {
				return err
			}
			last := pkg.specs[len(pkg.specs)-1]
			last.types = append(last.types, typ)
			buf = buf[typ.byteSize:]
		default:
			return errWrongType(t, ResTableTypeSpec, ResTableType)
		}
	}

	return nil
}

// TypeSpec provides a specification for the resources defined by a particular type.
type TypeSpec struct {
	chunkHeader
	id         uint8  // id-1 is name index in Package.typePool
	res0       uint8  // must be 0
	res1       uint16 // must be 0
	entryCount uint32 // number of uint32 entry configuration masks that follow

	entries []uint32 // entry configuration masks
	types   []*Type
}

func (spec *TypeSpec) UnmarshalBinary(bin []byte) error {
	if err := (&spec.chunkHeader).UnmarshalBinary(bin); err != nil {
		return err
	}
	if spec.typ != ResTableTypeSpec {
		return errWrongType(spec.typ, ResTableTypeSpec)
	}
	spec.id = uint8(bin[8])
	spec.res0 = uint8(bin[9])
	spec.res1 = btou16(bin[10:])
	spec.entryCount = btou32(bin[12:])

	spec.entries = make([]uint32, spec.entryCount)
	for i := range spec.entries {
		spec.entries[i] = btou32(bin[16+i*4:])
	}

	return nil
}

// Type provides a collection of entries for a specific device configuration.
type Type struct {
	chunkHeader
	id           uint8
	res0         uint8  // must be 0
	res1         uint16 // must be 0
	entryCount   uint32 // number of uint32 entry configuration masks that follow
	entriesStart uint32 // offset from header where Entry data starts

	// TODO implement and decode Config if strictly necessary
	// config Config // configuration this collection of entries is designed for (portrait, sw600dp, etc)

	indices []uint32 // values that map to typePool
	entries []*Entry
}

func (typ *Type) UnmarshalBinary(bin []byte) error {
	if err := (&typ.chunkHeader).UnmarshalBinary(bin); err != nil {
		return err
	}
	if typ.typ != ResTableType {
		return errWrongType(typ.typ, ResTableType)
	}

	typ.id = uint8(bin[8])
	typ.res0 = uint8(bin[9])
	typ.res1 = btou16(bin[10:])
	typ.entryCount = btou32(bin[12:])
	typ.entriesStart = btou32(bin[16:])

	if typ.res0 != 0 || typ.res1 != 0 {
		return fmt.Errorf("res0 res1 not zero")
	}

	buf := bin[typ.headerByteSize:typ.entriesStart]
	for len(buf) > 0 {
		typ.indices = append(typ.indices, btou32(buf))
		buf = buf[4:]
	}

	if len(typ.indices) != int(typ.entryCount) {
		return fmt.Errorf("indices len[%v] doesn't match entryCount[%v]", len(typ.indices), typ.entryCount)
	}
	typ.entries = make([]*Entry, typ.entryCount)

	for i, x := range typ.indices {
		if x == NoEntry {
			continue
		}
		nt := &Entry{}
		if err := nt.UnmarshalBinary(bin[typ.entriesStart+x:]); err != nil {
			return err
		}
		typ.entries[i] = nt
	}

	return nil
}

// Entry is a resource key typically followed by a value or resource map.
type Entry struct {
	size  uint16
	flags uint16
	key   PoolRef // ref into key pool

	// only filled if this is a map entry; when size is 16
	parent TableRef // id of parent mapping or zero if none
	count  uint32   // name and value pairs that follow for FlagComplex

	values []*Value
}

func (nt *Entry) UnmarshalBinary(bin []byte) error {
	nt.size = btou16(bin)
	nt.flags = btou16(bin[2:])
	nt.key = PoolRef(btou32(bin[4:]))

	if nt.size == 16 {
		nt.parent = TableRef(btou32(bin[8:]))
		nt.count = btou32(bin[12:])
		nt.values = make([]*Value, nt.count)
		for i := range nt.values {
			val := &Value{}
			if err := val.UnmarshalBinary(bin[16+i*12:]); err != nil {
				return err
			}
			nt.values[i] = val
		}
	} else {
		data := &Data{}
		if err := data.UnmarshalBinary(bin[8:]); err != nil {
			return err
		}
		// TODO boxing data not strictly correct as binary repr isn't of Value.
		nt.values = append(nt.values, &Value{0, data})
	}

	return nil
}

type Value struct {
	name TableRef
	data *Data
}

func (val *Value) UnmarshalBinary(bin []byte) error {
	val.name = TableRef(btou32(bin))
	val.data = &Data{}
	return val.data.UnmarshalBinary(bin[4:])
}

type DataType uint8

// explicitly defined for clarity and resolvability with apt source
const (
	DataNull             DataType = 0x00 // either 0 or 1 for resource undefined or empty
	DataReference        DataType = 0x01 // ResTable_ref, a reference to another resource table entry
	DataAttribute        DataType = 0x02 // attribute resource identifier
	DataString           DataType = 0x03 // index into the containing resource table's global value string pool
	DataFloat            DataType = 0x04 // single-precision floating point number
	DataDimension        DataType = 0x05 // complex number encoding a dimension value, such as "100in"
	DataFraction         DataType = 0x06 // complex number encoding a fraction of a container
	DataDynamicReference DataType = 0x07 // dynamic ResTable_ref, which needs to be resolved before it can be used like a TYPE_REFERENCE.
	DataIntDec           DataType = 0x10 // raw integer value of the form n..n
	DataIntHex           DataType = 0x11 // raw integer value of the form 0xn..n
	DataIntBool          DataType = 0x12 // either 0 or 1, for input "false" or "true"
	DataIntColorARGB8    DataType = 0x1c // raw integer value of the form #aarrggbb
	DataIntColorRGB8     DataType = 0x1d // raw integer value of the form #rrggbb
	DataIntColorARGB4    DataType = 0x1e // raw integer value of the form #argb
	DataIntColorRGB4     DataType = 0x1f // raw integer value of the form #rgb
)

type Data struct {
	ByteSize uint16
	Res0     uint8 // always 0, useful for debugging bad read offsets
	Type     DataType
	Value    uint32
}

func (d *Data) UnmarshalBinary(bin []byte) error {
	d.ByteSize = btou16(bin)
	d.Res0 = uint8(bin[2])
	d.Type = DataType(bin[3])
	d.Value = btou32(bin[4:])
	return nil
}

func (d *Data) MarshalBinary() ([]byte, error) {
	bin := make([]byte, 8)
	putu16(bin, d.ByteSize)
	bin[2] = byte(d.Res0)
	bin[3] = byte(d.Type)
	putu32(bin[4:], d.Value)
	return bin, nil
}
