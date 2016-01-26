package flashlight

// While in development mode we probably would not want auto-updates to be
// applied. Using a big number here prevents such auto-updates without
// disabling the feature completely. The "make package-*" tool will take care
// of bumping this version number so you don't have to do it by hand.
const (
	DefaultPackageVersion = "9999.99.99"
	PackageVersion        = DefaultPackageVersion
)
