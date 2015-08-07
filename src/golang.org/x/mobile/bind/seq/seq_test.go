// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package seq

import "testing"

func TestBuffer(t *testing.T) {
	buf := new(Buffer)
	buf.WriteInt64(1 << 42)
	buf.WriteInt32(1 << 13)
	buf.WriteUTF16("Hello, world")
	buf.WriteFloat64(4.02)
	buf.WriteFloat32(1.2)
	buf.WriteGoRef(new(int))
	buf.WriteGoRef(new(int))

	buf.Offset = 0

	if got, want := buf.ReadInt64(), int64(1<<42); got != want {
		t.Errorf("buf.ReadInt64()=%d, want %d", got, want)
	}
	if got, want := buf.ReadInt32(), int32(1<<13); got != want {
		t.Errorf("buf.ReadInt32()=%d, want %d", got, want)
	}
	if got, want := buf.ReadUTF16(), "Hello, world"; got != want {
		t.Errorf("buf.ReadUTF16()=%q, want %q", got, want)
	}
	if got, want := buf.ReadFloat64(), 4.02; got != want {
		t.Errorf("buf.ReadFloat64()=%f, want %f", got, want)
	}
	if got, want := buf.ReadFloat32(), float32(1.2); got != want {
		t.Errorf("buf.ReadFloat32()=%f, want %f", got, want)
	}
}
