// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Package key defines an event for physical keyboard keys.
//
// On-screen software keyboards do not send key events.
//
// See the golang.org/x/mobile/app package for details on the event model.
package key

import (
	"fmt"
	"strings"
)

// Event is a key event.
type Event struct {
	// Rune is the meaning of the key event as determined by the
	// operating system. The mapping is determined by system-dependent
	// current layout, modifiers, lock-states, etc.
	//
	// If non-negative, it is a Unicode codepoint: pressing the 'a' key
	// generates different Runes 'a' or 'A' (but the same Code) depending on
	// the state of the shift key.
	//
	// If -1, the key does not generate a Unicode codepoint. To distinguish
	// them, look at Code.
	Rune rune

	// Code is the identity of the physical key relative to a notional
	// "standard" keyboard, independent of current layout, modifiers,
	// lock-states, etc
	//
	// For standard key codes, its value matches USB HID key codes.
	// Compare its value to uint32-typed constants in this package, such
	// as CodeLeftShift and CodeEscape.
	// TODO(crawshaw): define "type Code uint32"
	//
	// Pressing the regular '2' key and number-pad '2' key (with Num-Lock)
	// generate different Codes (but the same Rune).
	Code uint32

	// Modifiers is a bitmask representing a set of modifier keys: ModShift,
	// ModAlt, etc.
	Modifiers Modifiers

	// Direction is the direction of the key event: DirPress, DirRelease,
	// or DirNone (for key repeats).
	Direction Direction

	// TODO: add a Device ID, for multiple input devices?
	// TODO: add a time.Time?
}

// Direction is the direction of the key event.
type Direction uint8

const (
	DirNone    Direction = 0
	DirPress   Direction = 1
	DirRelease Direction = 2
)

// Modifiers is a bitmask representing a set of modifier keys.
type Modifiers uint32

const (
	ModShift   Modifiers = 1 << 0
	ModControl Modifiers = 1 << 1
	ModAlt     Modifiers = 1 << 2
	ModMeta    Modifiers = 1 << 3 // called "Command" on OS X
)

// Physical key codes.
//
// For standard key codes, its value matches USB HID key codes.
// TODO: add missing codes.
const (
	CodeA = 4
	CodeB = 5
	CodeC = 6
	CodeD = 7
	CodeE = 8
	CodeF = 9
	CodeG = 10
	CodeH = 11
	CodeI = 12
	CodeJ = 13
	CodeK = 14
	CodeL = 15
	CodeM = 16
	CodeN = 17
	CodeO = 18
	CodeP = 19
	CodeQ = 20
	CodeR = 21
	CodeS = 22
	CodeT = 23
	CodeU = 24
	CodeV = 25
	CodeW = 26
	CodeX = 27
	CodeY = 28
	CodeZ = 29

	Code1 = 30
	Code2 = 31
	Code3 = 32
	Code4 = 33
	Code5 = 34
	Code6 = 35
	Code7 = 36
	Code8 = 37
	Code9 = 38
	Code0 = 39

	CodeReturn    = 40
	CodeEscape    = 41
	CodeBackspace = 42
	CodeTab       = 43

	CodeF1  = 58
	CodeF2  = 59
	CodeF3  = 60
	CodeF4  = 61
	CodeF5  = 62
	CodeF6  = 63
	CodeF7  = 64
	CodeF8  = 65
	CodeF9  = 66
	CodeF10 = 67
	CodeF11 = 68
	CodeF12 = 69

	CodePageUp   = 75
	CodePageDown = 78

	CodeRightArrow = 79
	CodeLeftArrow  = 80
	CodeDownArrow  = 81
	CodeUpArrow    = 82

	CodeKeypadNumLockAndClear = 83
	CodeKeypadSlash           = 84
	CodeKeypadAsterisk        = 85
	CodeKeypadMinus           = 86
	CodeKeypadPlus            = 87
	CodeKeypadEnter           = 88
	CodeKeypad1               = 89
	CodeKeypad2               = 90
	CodeKeypad3               = 91
	CodeKeypad4               = 92
	CodeKeypad5               = 93
	CodeKeypad6               = 94
	CodeKeypad7               = 95
	CodeKeypad8               = 96
	CodeKeypad9               = 97
	CodeKeypad0               = 98
	CodeKeypadFullStop        = 99
	CodeKeypadEqualSign       = 103

	CodeF13 = 104
	CodeF14 = 105
	CodeF15 = 106
	CodeF16 = 107
	CodeF17 = 108
	CodeF18 = 109
	CodeF19 = 110
	CodeF20 = 111
	CodeF21 = 112
	CodeF22 = 113
	CodeF23 = 114
	CodeF24 = 115

	CodeHelp = 117

	CodeMute       = 127
	CodeVolumeUp   = 128
	CodeVolumeDown = 129

	CodeLeftControl  = 224
	CodeLeftShift    = 225
	CodeLeftAlt      = 226
	CodeLeftMeta     = 227
	CodeRightControl = 228
	CodeRightShift   = 229
	CodeRightAlt     = 230
	CodeRightMeta    = 231
)

// TODO: Given we use runes outside the unicode space, should we provide a
// printing function? Related: it's a little unfortunate that printing a
// key.Event with %v gives not very readable output like:
//	{100 7 key.Modifiers() Press}

var mods = [...]struct {
	m Modifiers
	s string
}{
	{ModShift, "Shift"},
	{ModControl, "Control"},
	{ModAlt, "Alt"},
	{ModMeta, "Meta"},
}

func (m Modifiers) String() string {
	var match []string
	for _, mod := range mods {
		if mod.m&m != 0 {
			match = append(match, mod.s)
		}
	}
	return "key.Modifiers(" + strings.Join(match, "|") + ")"
}

func (d Direction) String() string {
	switch d {
	case DirNone:
		return "None"
	case DirPress:
		return "Press"
	case DirRelease:
		return "Release"
	default:
		return fmt.Sprintf("key.Direction(%d)", d)
	}
}
