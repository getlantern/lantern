package semver

import (
	"reflect"
	"testing"
)

func TestSort(t *testing.T) {
	v100, _ := New("1.0.0")
	v010, _ := New("0.1.0")
	v001, _ := New("0.0.1")
	versions := []Version{v010, v100, v001}
	Sort(versions)

	correct := []Version{v001, v010, v100}
	if !reflect.DeepEqual(versions, correct) {
		t.Fatalf("Sort returned wrong order: %s", versions)
	}
}

func BenchmarkSort(b *testing.B) {
	v100, _ := New("1.0.0")
	v010, _ := New("0.1.0")
	v001, _ := New("0.0.1")
	b.ReportAllocs()
	b.ResetTimer()
	for n := 0; n < b.N; n++ {
		Sort([]Version{v010, v100, v001})
	}
}
