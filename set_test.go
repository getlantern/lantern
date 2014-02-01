package set

import (
	"testing"
)

func Test_Union(t *testing.T) {
	s := New("1", "2", "3")
	r := New("3", "4", "5")
	x := New("5", "6", "7")

	u := Union(s, r, x)

	if u.Size() != 7 {
		t.Error("Union: the merged set doesn't have all items in it.")
	}

	if !u.Has("1", "2", "3", "4", "5", "6", "7") {
		t.Error("Union: merged items are not availabile in the set.")
	}

	y := Union()
	if y.Size() != 0 {
		t.Error("Union: should have zero items because nothing is passed")
	}

	z := Union(x)
	if z.Size() != 3 {
		t.Error("Union: the merged set doesn't have all items in it.")
	}

}

func Test_Difference(t *testing.T) {
	s := New("1", "2", "3")
	r := New("3", "4", "5")
	x := New("5", "6", "7")
	u := Difference(s, r, x)

	if u.Size() != 2 {
		t.Error("Difference: the set doesn't have all items in it.")
	}

	if !u.Has("1", "2") {
		t.Error("Difference: items are not availabile in the set.")
	}

	y := Difference()
	if y.Size() != 0 {
		t.Error("Difference: size should be zero")
	}

	z := Difference(s)
	if z.Size() != 3 {
		t.Error("Difference: size should be four")
	}
}

func BenchmarkSetEquality(b *testing.B) {
	s := New()
	u := New()

	for i := 0; i < b.N; i++ {
		s.Add(i)
		u.Add(i)
	}

	b.ResetTimer()

	for i := 0; i < b.N; i++ {
		s.IsEqual(u)
	}
}

func BenchmarkSubset(b *testing.B) {
	s := New()
	u := New()

	for i := 0; i < b.N; i++ {
		s.Add(i)
		u.Add(i)
	}

	b.ResetTimer()

	for i := 0; i < b.N; i++ {
		s.IsSubset(u)
	}
}

func benchmarkIntersection(b *testing.B, numberOfItems int) {
	s := New()
	u := New()

	for i := 0; i < numberOfItems; i++ {
		s.Add(i)
		u.Add(i)
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		s.Intersection(u)
	}

}

func BenchmarkIntersection10(b *testing.B) {
	benchmarkIntersection(b, 10)
}

func BenchmarkIntersection100(b *testing.B) {
	benchmarkIntersection(b, 100)
}

func BenchmarkIntersection1000(b *testing.B) {
	benchmarkIntersection(b, 1000)
}

func BenchmarkIntersection10000(b *testing.B) {
	benchmarkIntersection(b, 10000)
}

func BenchmarkIntersection100000(b *testing.B) {
	benchmarkIntersection(b, 100000)
}

func BenchmarkIntersection1000000(b *testing.B) {
	benchmarkIntersection(b, 1000000)
}
