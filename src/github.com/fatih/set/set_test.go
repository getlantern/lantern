package set

import (
	"reflect"
	"testing"
)

func Test_Union(t *testing.T) {
	s := newTS()
	s.Add("1", "2", "3")
	r := newTS()
	r.Add("3", "4", "5")
	x := newNonTS()
	x.Add("5", "6", "7")

	u := Union(s, r, x)
	if settype := reflect.TypeOf(u).String(); settype != "*set.Set" {
		t.Error("Union should derive its set type from the first passed set, got", settype)
	}
	if u.Size() != 7 {
		t.Error("Union: the merged set doesn't have all items in it.")
	}

	if !u.Has("1", "2", "3", "4", "5", "6", "7") {
		t.Error("Union: merged items are not availabile in the set.")
	}

	z := Union(x, r)
	if z.Size() != 5 {
		t.Error("Union: Union of 2 sets doesn't have the proper number of items.")
	}
	if settype := reflect.TypeOf(z).String(); settype != "*set.SetNonTS" {
		t.Error("Union should derive its set type from the first passed set, got", settype)
	}

}

func Test_Difference(t *testing.T) {
	s := newTS()
	s.Add("1", "2", "3")
	r := newTS()
	r.Add("3", "4", "5")
	x := newNonTS()
	x.Add("5", "6", "7")

	u := Difference(s, r, x)

	if u.Size() != 2 {
		t.Error("Difference: the set doesn't have all items in it.")
	}

	if !u.Has("1", "2") {
		t.Error("Difference: items are not availabile in the set.")
	}

	y := Difference(r, r)
	if y.Size() != 0 {
		t.Error("Difference: size should be zero")
	}

}

func Test_Intersection(t *testing.T) {
	s1 := newTS()
	s1.Add("1", "3", "4", "5")
	s2 := newTS()
	s2.Add("3", "5", "6")
	s3 := newTS()
	s3.Add("4", "5", "6", "7")
	u := Intersection(s1, s2, s3)

	if u.Size() != 1 {
		t.Error("Intersection: the set doesn't have all items in it.")
	}

	if !u.Has("5") {
		t.Error("Intersection: items after intersection are not availabile in the set.")
	}
}

func Test_Intersection2(t *testing.T) {
	s1 := newTS()
	s1.Add("1", "3", "4", "5")
	s2 := newTS()
	s2.Add("5", "6")
	i := Intersection(s1, s2)

	if i.Size() != 1 {
		t.Error("Intersection: size should be 1, it was", i.Size())
	}

	if !i.Has("5") {
		t.Error("Intersection: items after intersection are not availabile in the set.")
	}
}

func Test_SymmetricDifference(t *testing.T) {
	s := newTS()
	s.Add("1", "2", "3")
	r := newTS()
	r.Add("3", "4", "5")
	u := SymmetricDifference(s, r)

	if u.Size() != 4 {
		t.Error("SymmetricDifference: the set doesn't have all items in it.")
	}

	if !u.Has("1", "2", "4", "5") {
		t.Error("SymmetricDifference: items are not availabile in the set.")
	}
}

func Test_StringSlice(t *testing.T) {
	s := newTS()
	s.Add("san francisco", "istanbul", 3.14, 1321, "ankara")
	u := StringSlice(s)

	if len(u) != 3 {
		t.Error("StringSlice: slice should only have three items")
	}

	for _, item := range u {
		r := reflect.TypeOf(item)
		if r.Kind().String() != "string" {
			t.Error("StringSlice: slice item should be a string")
		}
	}
}

func Test_IntSlice(t *testing.T) {
	s := newTS()
	s.Add("san francisco", "istanbul", 3.14, 1321, "ankara", 8876)
	u := IntSlice(s)

	if len(u) != 2 {
		t.Error("IntSlice: slice should only have two items")
	}

	for _, item := range u {
		r := reflect.TypeOf(item)
		if r.Kind().String() != "int" {
			t.Error("Intslice: slice item should be a int")
		}
	}
}

func BenchmarkSetEquality(b *testing.B) {
	s := newTS()
	u := newTS()

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
	s := newTS()
	u := newTS()

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
	s1 := newTS()
	s2 := newTS()

	for i := 0; i < numberOfItems/2; i++ {
		s1.Add(i)
	}
	for i := 0; i < numberOfItems; i++ {
		s2.Add(i)
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		Intersection(s1, s2)
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
