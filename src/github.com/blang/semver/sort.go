package semver

import (
	"sort"
)

type Versions []Version

func (s Versions) Len() int {
	return len(s)
}

func (s Versions) Swap(i, j int) {
	s[i], s[j] = s[j], s[i]
}

func (s Versions) Less(i, j int) bool {
	return s[i].LT(s[j])
}

// Sort sorts a slice of versions
func Sort(versions []Version) {
	sort.Sort(Versions(versions))
}
