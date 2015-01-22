package statreporter

import (
	"fmt"
	"sort"

	"github.com/getlantern/flashlight/globals"
)

const (
	increments = "increments"
	gauges     = "gauges"
	members    = "multiMembers"
)

// DimGroup represents a group of dimensions for categorizing stats.
type DimGroup struct {
	dims map[string]string
}

// UpdateBuilder is an intermediary data structure used in preparing an update
// for submission to statreporter.
type UpdateBuilder struct {
	dg       *DimGroup
	category string
	key      string
}

type update struct {
	dg       *DimGroup
	category string
	key      string
	action   interface{} // one of set, add or member
}

type set int64
type add int64
type member string

// Dim constructs a DimGroup starting with a single dimension.
func Dim(key string, value string) *DimGroup {
	return &DimGroup{map[string]string{key: value}}
}

func CountryDim() *DimGroup {
	return Country(globals.Country)
}

func Country(country string) *DimGroup {
	return Dim(countryDim, country)
}

// And creates a new DimGroup that adds the given dim to the existing ones in
// the group.
func (dg *DimGroup) And(key string, value string) *DimGroup {
	newDims := map[string]string{key: value}
	for k, v := range dg.dims {
		newDims[k] = v
	}
	return &DimGroup{newDims}
}

func (dg *DimGroup) WithCountry() *DimGroup {
	return dg.And(countryDim, globals.Country)
}

// String returns a string representation of this DimGroup with keys in
// alphabetical order, making it suitable for using as a key representing this
// DimGroup.
func (dg *DimGroup) String() string {
	// Sort keys
	keys := make([]string, len(dg.dims))
	i := 0
	for key, _ := range dg.dims {
		keys[i] = key
		i = i + 1
	}
	sort.Strings(keys)

	// Build string
	s := ""
	sep := ""
	for _, key := range keys {
		s = fmt.Sprintf("%s%s%s=%s", s, sep, key, dg.dims[key])
		sep = ","
	}
	return s
}

func (dg *DimGroup) Increment(key string) *UpdateBuilder {
	return &UpdateBuilder{
		dg,
		increments,
		key,
	}
}

func (dg *DimGroup) Gauge(key string) *UpdateBuilder {
	return &UpdateBuilder{
		dg,
		gauges,
		key,
	}
}

func (dg *DimGroup) Member(key string, val string) {
	postUpdate(&update{
		dg,
		members,
		key,
		member(val),
	})
}

func (b *UpdateBuilder) Add(val int64) {
	postUpdate(&update{
		b.dg,
		b.category,
		b.key,
		add(val),
	})
}

func (b *UpdateBuilder) Set(val int64) {
	postUpdate(&update{
		b.dg,
		b.category,
		b.key,
		set(val),
	})
}
