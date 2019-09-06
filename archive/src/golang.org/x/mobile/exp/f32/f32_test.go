// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package f32

import (
	"bytes"
	"encoding/binary"
	"math"
	"testing"
)

func TestAffineTranslationsCommute(t *testing.T) {
	a := &Affine{
		{1, 0, 3},
		{0, 1, 4},
	}
	b := &Affine{
		{1, 0, 20},
		{0, 1, 30},
	}

	var m0, m1 Affine
	m0.Mul(a, b)
	m1.Mul(b, a)
	if !m0.Eq(&m1, 0) {
		t.Errorf("m0, m1 differ.\nm0: %v\nm1: %v", m0, m1)
	}
}

func TestAffineMat3Equivalence(t *testing.T) {
	a0 := Affine{
		{13, 19, 37},
		{101, 149, 311},
	}
	m0 := Mat3{
		a0[0],
		a0[1],
		{0, 0, 1},
	}

	a1 := Affine{
		{1009, 1051, 1087},
		{563, 569, 571},
	}
	m1 := Mat3{
		a1[0],
		a1[1],
		{0, 0, 1},
	}

	a2 := Affine{}
	a2.Mul(&a0, &a1)
	m2 := Mat3{
		a2[0],
		a2[1],
		{0, 0, 1},
	}

	mm := Mat3{}
	mm.Mul(&m0, &m1)

	if !m2.Eq(&mm, 0) {
		t.Errorf("m2, mm differ.\nm2: %v\nmm: %v", m2, mm)
	}
}

var x3 = Mat3{
	{0, 1, 2},
	{3, 4, 5},
	{6, 7, 8},
}

var x3sq = Mat3{
	{15, 18, 21},
	{42, 54, 66},
	{69, 90, 111},
}

var id3 = Mat3{
	{1, 0, 0},
	{0, 1, 0},
	{0, 0, 1},
}

func TestMat3Mul(t *testing.T) {
	tests := []struct{ m0, m1, want Mat3 }{
		{x3, id3, x3},
		{id3, x3, x3},
		{x3, x3, x3sq},
		{
			Mat3{
				{+1.811, +0.000, +0.000},
				{+0.000, +2.414, +0.000},
				{+0.000, +0.000, -1.010},
			},
			Mat3{
				{+0.992, -0.015, +0.123},
				{+0.000, +0.992, +0.123},
				{-0.124, -0.122, +0.985},
			},
			Mat3{
				{+1.797, -0.027, +0.223},
				{+0.000, +2.395, +0.297},
				{+0.125, +0.123, -0.995},
			},
		},
	}

	for i, test := range tests {
		got := Mat3{}
		got.Mul(&test.m0, &test.m1)
		if !got.Eq(&test.want, 0.01) {
			t.Errorf("test #%d:\n%s *\n%s =\n%s, want\n%s", i, test.m0, test.m1, got, test.want)
		}
	}
}

func TestMat3SelfMul(t *testing.T) {
	m := x3
	m.Mul(&m, &m)
	if !m.Eq(&x3sq, 0) {
		t.Errorf("m, x3sq differ.\nm:    %v\nx3sq: %v", m, x3sq)
	}
}

var x4 = Mat4{
	{0, 1, 2, 3},
	{4, 5, 6, 7},
	{8, 9, 10, 11},
	{12, 13, 14, 15},
}

var x4sq = Mat4{
	{56, 62, 68, 74},
	{152, 174, 196, 218},
	{248, 286, 324, 362},
	{344, 398, 452, 506},
}

var id4 = Mat4{
	{1, 0, 0, 0},
	{0, 1, 0, 0},
	{0, 0, 1, 0},
	{0, 0, 0, 1},
}

func TestMat4Eq(t *testing.T) {
	tests := []struct {
		m0, m1 Mat4
		eq     bool
	}{
		{x4, x4, true},
		{id4, id4, true},
		{x4, id4, false},
	}

	for _, test := range tests {
		got := test.m0.Eq(&test.m1, 0.01)
		if got != test.eq {
			t.Errorf("Eq=%v, want %v for\n%s\n%s", got, test.eq, test.m0, test.m1)
		}
	}
}

func TestMat4Mul(t *testing.T) {
	tests := []struct{ m0, m1, want Mat4 }{
		{x4, id4, x4},
		{id4, x4, x4},
		{x4, x4, x4sq},
		{
			Mat4{
				{+1.811, +0.000, +0.000, +0.000},
				{+0.000, +2.414, +0.000, +0.000},
				{+0.000, +0.000, -1.010, -1.000},
				{+0.000, +0.000, -2.010, +0.000},
			},
			Mat4{
				{+0.992, -0.015, +0.123, +0.000},
				{+0.000, +0.992, +0.123, +0.000},
				{-0.124, -0.122, +0.985, +0.000},
				{-0.000, -0.000, -8.124, +1.000},
			},
			Mat4{
				{+1.797, -0.027, +0.223, +0.000},
				{+0.000, +2.395, +0.297, +0.000},
				{+0.125, +0.123, +7.129, -1.000},
				{+0.249, +0.245, -1.980, +0.000},
			},
		},
	}

	for i, test := range tests {
		got := Mat4{}
		got.Mul(&test.m0, &test.m1)
		if !got.Eq(&test.want, 0.01) {
			t.Errorf("test #%d:\n%s *\n%s =\n%s, want\n%s", i, test.m0, test.m1, got, test.want)
		}
	}
}

func TestMat4LookAt(t *testing.T) {
	tests := []struct {
		eye, center, up Vec3
		want            Mat4
	}{
		{
			Vec3{1, 1, 8}, Vec3{0, 0, 0}, Vec3{0, 1, 0},
			Mat4{
				{0.992, -0.015, 0.123, 0.000},
				{0.000, 0.992, 0.123, 0.000},
				{-0.124, -0.122, 0.985, 0.000},
				{-0.000, -0.000, -8.124, 1.000},
			},
		},
		{
			Vec3{4, 5, 7}, Vec3{0.1, 0.2, 0.3}, Vec3{0, -1, 0},
			Mat4{
				{-0.864, 0.265, 0.428, 0.000},
				{0.000, -0.850, 0.526, 0.000},
				{0.503, 0.455, 0.735, 0.000},
				{-0.064, 0.007, -9.487, 1.000},
			},
		},
	}

	for _, test := range tests {
		got := Mat4{}
		got.LookAt(&test.eye, &test.center, &test.up)
		if !got.Eq(&test.want, 0.01) {
			t.Errorf("LookAt(%s,%s%s) =\n%s\nwant\n%s", test.eye, test.center, test.up, got, test.want)
		}
	}

}

func TestMat4Perspective(t *testing.T) {
	want := Mat4{
		{1.811, 0.000, 0.000, 0.000},
		{0.000, 2.414, 0.000, 0.000},
		{0.000, 0.000, -1.010, -1.000},
		{0.000, 0.000, -2.010, 0.000},
	}
	got := Mat4{}

	got.Perspective(Radian(math.Pi/4), 4.0/3, 1, 200)

	if !got.Eq(&want, 0.01) {
		t.Errorf("got\n%s\nwant\n%s", got, want)
	}

}

func TestMat4Rotate(t *testing.T) {
	want := &Mat4{
		{2.000, 1.000, -0.000, 3.000},
		{6.000, 5.000, -4.000, 7.000},
		{10.000, 9.000, -8.000, 11.000},
		{14.000, 13.000, -12.000, 15.000},
	}

	got := new(Mat4)
	got.Rotate(&x4, Radian(math.Pi/2), &Vec3{0, 1, 0})

	if !got.Eq(want, 0.01) {
		t.Errorf("got\n%s\nwant\n%s", got, want)
	}
}

func TestMat4Scale(t *testing.T) {
	want := &Mat4{
		{0 * 2, 1 * 3, 2 * 4, 3 * 1},
		{4 * 2, 5 * 3, 6 * 4, 7 * 1},
		{8 * 2, 9 * 3, 10 * 4, 11 * 1},
		{12 * 2, 13 * 3, 14 * 4, 15 * 1},
	}

	got := new(Mat4)
	got.Scale(&x4, 2, 3, 4)

	if !got.Eq(want, 0.01) {
		t.Errorf("got\n%s\nwant\n%s", got, want)
	}
}

func TestMat4Translate(t *testing.T) {
	want := &Mat4{
		{0, 1, 2, 0*0.1 + 1*0.2 + 2*0.3 + 3*1},
		{4, 5, 6, 4*0.1 + 5*0.2 + 6*0.3 + 7*1},
		{8, 9, 10, 8*0.1 + 9*0.2 + 10*0.3 + 11*1},
		{12, 13, 14, 12*0.1 + 13*0.2 + 14*0.3 + 15*1},
	}

	got := new(Mat4)
	got.Translate(&x4, 0.1, 0.2, 0.3)

	if !got.Eq(want, 0.01) {
		t.Errorf("got\n%s\nwant\n%s", got, want)
	}
}

func testTrig(t *testing.T, gotFunc func(float32) float32, wantFunc func(float64) float64) {
	nBad := 0
	for a := float32(-9); a < +9; a += .01 {
		got := gotFunc(a)
		want := float32(wantFunc(float64(a)))
		diff := got - want
		if diff < 0 {
			diff = -diff
		}
		if diff > 0.001 {
			if nBad++; nBad == 10 {
				t.Errorf("too many failures")
				break
			}
			t.Errorf("a=%+.2f: got %+.4f, want %+.4f, diff=%.4f", a, got, want, diff)
		}
	}
}

func TestCos(t *testing.T) { testTrig(t, Cos, math.Cos) }
func TestSin(t *testing.T) { testTrig(t, Sin, math.Sin) }
func TestTan(t *testing.T) { testTrig(t, Tan, math.Tan) }

func BenchmarkSin(b *testing.B) {
	for i := 0; i < b.N; i++ {
		for a := 0; a < 3141; a++ {
			Sin(float32(a) / 1000)
		}
	}
}

func TestBytes(t *testing.T) {
	testCases := []struct {
		byteOrder binary.ByteOrder
		want      []byte
	}{{
		binary.BigEndian,
		[]byte{
			// The IEEE 754 binary32 format is 1 sign bit, 8 exponent bits and 23 fraction bits.
			0x00, 0x00, 0x00, 0x00, // float32(+0.00) is 0 0000000_0 0000000_00000000_00000000
			0x3f, 0xa0, 0x00, 0x00, // float32(+1.25) is 0 0111111_1 0100000_00000000_00000000
			0xc0, 0x00, 0x00, 0x00, // float32(-2.00) is 1 1000000_0 0000000_00000000_00000000
		},
	}, {
		binary.LittleEndian,
		[]byte{
			0x00, 0x00, 0x00, 0x00,
			0x00, 0x00, 0xa0, 0x3f,
			0x00, 0x00, 0x00, 0xc0,
		},
	}}

	for _, tc := range testCases {
		got := Bytes(tc.byteOrder, +0.00, +1.25, -2.00)
		if !bytes.Equal(got, tc.want) {
			t.Errorf("%v:\ngot  % x\nwant % x", tc.byteOrder, got, tc.want)
		}
	}
}
