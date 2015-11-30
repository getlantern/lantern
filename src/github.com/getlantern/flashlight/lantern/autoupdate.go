// +build !prod

package lantern

// While in development mode we probably would not want auto-updates to be
// applied. Using a big number here prevents such auto-updates without
// disabling the feature completely. The "make package-*" tool will take care
// of bumping this version number so you don't have to do it by hand.
const (
	defaultPackageVersion = "9999.99.99"
	packageVersion        = defaultPackageVersion
)

// This is the public key of the BNS cert. Incoming updates will be signed to
// prevent MITM attacks.
const packagePublicKey = `-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAxeReZ0VHDQ+/XYEHhFq0
krT+a/+/mlhCkgJ/605KmPXqBv8qo5f1iK6C+TQ87264J4Z9yw0tRwcdY1/ofpH7
Tywq3pBOgfrnnP9gFtquQ/tgzVkorQ0L51w9HLZ3cCjpaLpofIaztgbCIzsCT6kV
Nx6Sd/4KBSuThhMEnP5pu5Wxr4/lujIpTeVEXzljQMxqX+58ISeXYx6SxLXx5Vgj
1IB6NJwjg7r4Nzg/zUH0ZkCWj3rDWo6itIoeo61o+hPQAjH23TCKOn8Ssaejocyg
CrcOc7aqfGuVM3HuHxtXsjYPqJMVHiXKosi9HcHo5BACPT0FkrZIwz3k6Vy1h7nB
HQIDAQAB
-----END PUBLIC KEY-----`
