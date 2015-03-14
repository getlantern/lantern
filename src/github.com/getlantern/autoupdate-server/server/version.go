package server

import (
	"regexp"
	"strconv"
	"strings"
)

var (
	updateAssetRe = regexp.MustCompile(`^autoupdate-binary-(darwin|windows|linux)-(arm|386|amd64)\.?.*$`)
	versionTagRe  = regexp.MustCompile(`^v[0-9][0-9a-z\-\.]*$`)
	nonNumericRe  = regexp.MustCompile(`[^0-9\-\.]`)
)

// Output values for VersionCompare
const (
	Lower  = -1
	Higher = 1
	Equal  = 0
)

func max(x int, y int) int {
	if x > y {
		// x is greater than y.
		return x
	}
	// y must be greater than or equal to x.
	return y
}

// VersionCompare returns Lower if the given comp value is lower than the base
// value, Higher if comp is higher and Equal if the two of them are equal.
func VersionCompare(base string, comp string) int {
	// Splitting string values into an array of numeric values.
	baseV := numericValue(base)
	compV := numericValue(comp)

	cln := len(compV)
	bln := len(baseV)

	top := max(bln, cln)

	// Comparing from left to right.
	for i := 0; i < top; i++ {

		bv := 0
		cv := 0

		if i < bln {
			bv = baseV[i]
		}

		if i < cln {
			cv = compV[i]
		}

		// Stopping at first disequality.
		if cv > bv {
			return Higher
		} else if cv < bv {
			return Lower
		}

	}

	return Equal
}

// numericValue transforms an string value into an array of integers.
func numericValue(s string) (v []int) {
	// Removing unuseful stuff.
	s = nonNumericRe.ReplaceAllString(s, "")
	// Replacing - with . for easier splitting.
	s = strings.Replace(s, "-", ".", -1)
	n := strings.Split(s, ".")
	// Allocating space for v.
	v = make([]int, 0, len(n))
	for i := range n {
		nv := 0
		if n[i] != "" {
			nv, _ = strconv.Atoi(n[i])
		}
		v = append(v, nv)
	}
	return v
}

func isVersionTag(s string) bool {
	return versionTagRe.MatchString(s)
}

func isUpdateAsset(s string) bool {
	return updateAssetRe.MatchString(s)
}
