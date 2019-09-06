// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package font

/*
#cgo darwin LDFLAGS: -framework CoreFoundation -framework CoreText
#include <CoreFoundation/CFArray.h>
#include <CoreFoundation/CFBase.h>
#include <CoreFoundation/CFData.h>
#include <CoreText/CTFont.h>
*/
import "C"
import "unsafe"

func buildFont(f C.CTFontRef) []byte {
	ctags := C.CTFontCopyAvailableTables(f, C.kCTFontTableOptionExcludeSynthetic)
	tagsCount := C.CFArrayGetCount(ctags)

	var tags []uint32
	var dataRefs []C.CFDataRef
	var dataLens []uint32

	for i := C.CFIndex(0); i < tagsCount; i++ {
		tag := (C.CTFontTableTag)((uintptr)(C.CFArrayGetValueAtIndex(ctags, i)))
		dataRef := C.CTFontCopyTable(f, tag, 0) // retained
		tags = append(tags, uint32(tag))
		dataRefs = append(dataRefs, dataRef)
		dataLens = append(dataLens, uint32(C.CFDataGetLength(dataRef)))
	}

	totalLen := 0
	for _, l := range dataLens {
		totalLen += int(l)
	}

	// Big-endian output.
	buf := make([]byte, 0, 12+16*len(tags)+totalLen)
	write16 := func(x uint16) { buf = append(buf, byte(x>>8), byte(x)) }
	write32 := func(x uint32) { buf = append(buf, byte(x>>24), byte(x>>16), byte(x>>8), byte(x)) }

	// File format description: http://www.microsoft.com/typography/otspec/otff.htm
	write32(0x00010000)        // version 1.0
	write16(uint16(len(tags))) // numTables
	write16(0)                 // searchRange
	write16(0)                 // entrySelector
	write16(0)                 // rangeShift

	// Table tags, includes offsets into following data segments.
	offset := uint32(12 + 16*len(tags)) // offset starts after table tags
	for i, tag := range tags {
		write32(tag)
		write32(0)
		write32(offset)
		write32(dataLens[i])
		offset += dataLens[i]
	}

	// Data segments.
	for i, dataRef := range dataRefs {
		data := (*[1<<31 - 2]byte)((unsafe.Pointer)(C.CFDataGetBytePtr(dataRef)))[:dataLens[i]]
		buf = append(buf, data...)
		C.CFRelease(C.CFTypeRef(dataRef))
	}

	return buf
}

func buildDefault() ([]byte, error) {
	return buildFont(C.CTFontCreateUIFontForLanguage(C.kCTFontSystemFontType, 0, nil)), nil
}

func buildMonospace() ([]byte, error) {
	return buildFont(C.CTFontCreateUIFontForLanguage(C.kCTFontUserFixedPitchFontType, 0, nil)), nil
}
