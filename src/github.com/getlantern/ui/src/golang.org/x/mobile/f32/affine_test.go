package f32

import (
	"math"
	"testing"
)

var xyTests = []struct {
	x, y float32
}{
	{0, 0},
	{1, 1},
	{2, 3},
	{6.5, 4.3},
}

var a = Affine{
	{3, 4, 5},
	{6, 7, 8},
}

func TestInverse(t *testing.T) {
	wantInv := Affine{
		{-2.33333, 1.33333, 1},
		{2, -1, -2},
	}
	var gotInv Affine
	gotInv.Inverse(&a)
	if !gotInv.Eq(&wantInv, 0.01) {
		t.Errorf("Inverse: got %s want %s", gotInv, wantInv)
	}

	var wantId, gotId Affine
	wantId.Identity()
	gotId.Mul(&a, &wantInv)
	if !gotId.Eq(&wantId, 0.01) {
		t.Errorf("Identity #0: got %s want %s", gotId, wantId)
	}
	gotId.Mul(&wantInv, &a)
	if !gotId.Eq(&wantId, 0.01) {
		t.Errorf("Identity #1: got %s want %s", gotId, wantId)
	}
}

func TestAffineScale(t *testing.T) {
	for _, test := range xyTests {
		want := a
		want.Mul(&want, &Affine{{test.x, 0, 0}, {0, test.y, 0}})
		got := a
		got.Scale(&got, test.x, test.y)

		if !got.Eq(&want, 0.01) {
			t.Errorf("(%.2f, %.2f): got %s want %s", test.x, test.y, got, want)
		}
	}
}

func TestAffineTranslate(t *testing.T) {
	for _, test := range xyTests {
		want := a
		want.Mul(&want, &Affine{{1, 0, test.x}, {0, 1, test.y}})
		got := a
		got.Translate(&got, test.x, test.y)

		if !got.Eq(&want, 0.01) {
			t.Errorf("(%.2f, %.2f): got %s want %s", test.x, test.y, got, want)
		}
	}

}

func TestAffineRotate(t *testing.T) {
	want := Affine{
		{-4.000, 3.000, 5.000},
		{-7.000, 6.000, 8.000},
	}
	got := a
	got.Rotate(&got, math.Pi/2)
	if !got.Eq(&want, 0.01) {
		t.Errorf("rotate π: got %s want %s", got, want)
	}

	want = a
	got = a
	got.Rotate(&got, 2*math.Pi)
	if !got.Eq(&want, 0.01) {
		t.Errorf("rotate 2π: got %s want %s", got, want)
	}

	got = a
	got.Rotate(&got, math.Pi)
	got.Rotate(&got, math.Pi)
	if !got.Eq(&want, 0.01) {
		t.Errorf("rotate π then π: got %s want %s", got, want)
	}

	got = a
	got.Rotate(&got, math.Pi/3)
	got.Rotate(&got, -math.Pi/3)
	if !got.Eq(&want, 0.01) {
		t.Errorf("rotate π/3 then -π/3: got %s want %s", got, want)
	}
}

func TestAffineScaleTranslate(t *testing.T) {
	mulVec := func(m *Affine, v [2]float32) (mv [2]float32) {
		mv[0] = m[0][0]*v[0] + m[0][1]*v[1] + m[0][2]
		mv[1] = m[1][0]*v[0] + m[1][1]*v[1] + m[1][2]
		return mv
	}
	v := [2]float32{1, 10}

	var sThenT Affine
	sThenT.Identity()
	sThenT.Scale(&sThenT, 13, 17)
	sThenT.Translate(&sThenT, 101, 151)
	wantSTT := [2]float32{
		13 * (101 + 1),
		17 * (151 + 10),
	}
	if got := mulVec(&sThenT, v); got != wantSTT {
		t.Errorf("S then T: got %v, want %v", got, wantSTT)
	}

	var tThenS Affine
	tThenS.Identity()
	tThenS.Translate(&tThenS, 101, 151)
	tThenS.Scale(&tThenS, 13, 17)
	wantTTS := [2]float32{
		101 + (13 * 1),
		151 + (17 * 10),
	}
	if got := mulVec(&tThenS, v); got != wantTTS {
		t.Errorf("T then S: got %v, want %v", got, wantTTS)
	}
}
