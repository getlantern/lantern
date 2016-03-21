package osversion

import (
	"github.com/blang/semver"
)

func GetSemanticVersion() (semver.Version, error) {
	str, err := GetString()
	if err != nil {
		return semver.Version{}, err
	}

	return semver.Make(str)
}
