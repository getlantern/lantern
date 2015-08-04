package server

import (
	"github.com/blang/semver"
)

const (
	manotoBeta8        = `2.0.0-beta8+manoto`
	manotoBeta8Upgrade = `2.0.0+manoto`
)

var (
	manotoBeta8Checksums = []string{
		`e0997b393a6bc8d6e6e32865b6bf0ea127d3589f06eaf58039280d06743a5170`, // darwin amd64
		`4fbd6a87119478d166148b8dba589bdf73345c9ca836faaaed14cfda90eb516c`, // linux 386
		`ad83f23b6330dbe561d4a29e8183385ade585ae6ac02bf80a874b73ea0b0edf8`, // linux amd64
		`b949fef4e0f7824f5de879337688020013bd75a67b580e9db239cdb138b4bfb9`, // windows 386
	}
)

func hasManotoChecksum(c string) bool {
	for _, s := range manotoBeta8Checksums {
		if s == c {
			return true
		}
	}
	return false
}

func buildStringContainsManoto(v semver.Version) bool {
	for _, s := range v.Build {
		if s == "manoto" {
			return true
		}
	}
	return false
}
