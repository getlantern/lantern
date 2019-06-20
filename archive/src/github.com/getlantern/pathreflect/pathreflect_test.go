package pathreflect

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

type A struct {
	B      *B
	MapB   map[string]*B
	SliceB []*B
	E      map[string]interface{}
}

type B struct {
	S string
	I int
}

func TestSetOnEmptyRoot(t *testing.T) {
	var d *B

	err := Parse("B/E").Set(d, 50)
	assert.Error(t, err)
}

func TestSetOnEmptyParent(t *testing.T) {
	var d *B

	err := Parse("B/E/dude").Set(d, 50)
	assert.Error(t, err)
}

func TestNestedPrimitiveInStruct(t *testing.T) {
	d := makeData()

	ps := Parse("B///S/")
	pi := Parse("B/I")

	err := ps.Set(d, "10")
	assert.NoError(t, err, "Setting string field should succeed")

	err = pi.Set(d, 10)
	assert.NoError(t, err, "Setting int field should succeed")

	assert.Equal(t, "10", d.B.S, "string field should be updated")
	assert.Equal(t, 10, d.B.I, "int field should be updated")

	err = ps.Clear(d)
	assert.NoError(t, err, "Clearing string field should succeed")
	err = pi.Clear(d)
	assert.NoError(t, err, "Clearing int field should succeed")

	assert.Equal(t, "", d.B.S, "string field should reset to zero value after clearing")
	assert.Equal(t, 0, d.B.I, "int field should reset to zero value after clearing")

	zvs, err := ps.ZeroValue(d)
	assert.NoError(t, err, "Getting zero value of string should succeed")
	zvi, err := pi.ZeroValue(d)
	assert.NoError(t, err, "Getting zero value of int should succeed")

	assert.Equal(t, "", zvs, "Zero value of string should be empty string")
	assert.Equal(t, 0, zvi, "Zero value of int should be 0")
}

func TestNestedPrimitiveInMap(t *testing.T) {
	d := makeData()

	ps := Parse("MapB/3/S")
	pi := Parse("MapB/3/I")

	err := ps.Set(d, "10")
	assert.NoError(t, err, "Setting string field should succeed")

	err = pi.Set(d, 10)
	assert.NoError(t, err, "Setting int field should succeed")

	assert.Equal(t, "10", d.MapB["3"].S, "string field should be updated")
	assert.Equal(t, 10, d.MapB["3"].I, "int field should be updated")

	err = ps.Clear(d)
	assert.NoError(t, err, "Clearing string field should succeed")
	err = pi.Clear(d)
	assert.NoError(t, err, "Clearing int field should succeed")

	assert.Equal(t, "", d.MapB["3"].S, "string field should reset to zero value after clearing")
	assert.Equal(t, 0, d.MapB["3"].I, "int field should reset to zero value after clearing")
}

func TestNestedPrimitiveInSlice(t *testing.T) {
	d := makeData()

	ps := Parse("SliceB/1/S")
	pi := Parse("SliceB/1/I")

	err := ps.Set(d, "10")
	assert.NoError(t, err, "Setting string field should succeed")

	err = pi.Set(d, 10)
	assert.NoError(t, err, "Setting int field should succeed")

	assert.Equal(t, "10", d.SliceB[1].S, "string field should be updated")
	assert.Equal(t, 10, d.SliceB[1].I, "int field should be updated")

	err = ps.Clear(d)
	assert.NoError(t, err, "Clearing string field should succeed")
	err = pi.Clear(d)
	assert.NoError(t, err, "Clearing int field should succeed")

	assert.Equal(t, "", d.SliceB[1].S, "string field should reset to zero value after clearing")
	assert.Equal(t, 0, d.SliceB[1].I, "int field should reset to zero value after clearing")
}

func TestNestedField(t *testing.T) {
	d := makeData()
	orig := d.B

	p := Parse("B")
	err := p.Set(d, &B{
		S: "10",
		I: 10,
	})

	assert.NoError(t, err, "Setting struct should succeed")
	assert.Equal(t, "10", d.B.S, "string field should reflect value from new struct")
	assert.Equal(t, 10, d.B.I, "int field should reflect value from new struct")
	assert.NotEqual(t, d.B, orig, "struct should change")

	gotten, err := Parse("B/S").Get(d)
	assert.NoError(t, err, "Getting nested string should succeed")
	assert.Equal(t, "10", gotten, "Getting nested string should have gotten right value")

	err = p.Clear(d)
	assert.NoError(t, err, "Clearing struct should succeed")
	assert.Nil(t, d.B, "struct should be nil after clearing")

	zv, err := p.ZeroValue(d)
	assert.NoError(t, err, "Getting zero value of struct should succeed")
	assert.Equal(t, &B{}, zv, "Zero value of struct should match expected")
}

func TestNestedMapEntry(t *testing.T) {
	d := makeData()
	orig := d.MapB["3"]

	p := Parse("MapB/3")
	err := p.Set(d, &B{
		S: "10",
		I: 10,
	})

	assert.NoError(t, err, "Setting struct should succeed")
	assert.Equal(t, "10", d.MapB["3"].S, "string field should reflect value from new struct")
	assert.Equal(t, 10, d.MapB["3"].I, "int field should reflect value from new struct")
	assert.NotEqual(t, d.B, orig, "struct should change")

	gotten, err := Parse("MapB/3/S").Get(d)
	assert.NoError(t, err, "Getting nested string should succeed")
	assert.Equal(t, "10", gotten, "Getting nested string should have gotten right value")

	err = p.Clear(d)
	assert.NoError(t, err, "Clearing struct should succeed")
	_, found := d.MapB["3"]
	assert.False(t, found, "struct should be gone from map after clearing")

	zv, err := p.ZeroValue(d)
	assert.NoError(t, err, "Getting zero value of struct should succeed")
	assert.Equal(t, &B{}, zv, "Zero value of struct should match expected")
}

func TestNestedSliceEntry(t *testing.T) {
	d := makeData()
	orig := d.SliceB[1]

	p := Parse("SliceB/1")
	err := p.Set(d, &B{
		S: "10",
		I: 10,
	})

	assert.NoError(t, err, "Setting struct should succeed")
	assert.Equal(t, "10", d.SliceB[1].S, "string field should reflect value from new struct")
	assert.Equal(t, 10, d.SliceB[1].I, "int field should reflect value from new struct")
	assert.NotEqual(t, d.B, orig, "struct should change")

	err = p.Clear(d)
	assert.NoError(t, err, "Clearing struct should succeed")
	assert.Nil(t, d.SliceB[1], "struct should be gone from slice after clearing")
}

func TestZeroValue(t *testing.T) {
	d := map[string]map[string]int{
		"a": map[string]int{},
	}

	p := Parse("a/a2")
	zv, err := p.ZeroValue(d)
	assert.NoError(t, err, "Getting zero value for nonexistent element should succeed")
	assert.Equal(t, 0, zv, "Zero value for nonexistent element should be correct")
}

func makeData() *A {
	return &A{
		B: &B{
			S: "5",
			I: 5,
		},
		MapB: map[string]*B{
			"4": &B{
				S: "4",
				I: 4,
			},
			"3": &B{
				S: "3",
				I: 3,
			},
		},
		SliceB: []*B{
			&B{
				S: "0",
				I: 0,
			},
			&B{
				S: "1",
				I: 1,
			},
		},
	}
}
