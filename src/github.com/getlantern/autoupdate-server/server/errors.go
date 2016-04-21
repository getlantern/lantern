package server

import (
	"errors"
)

// Public errors
var (
	ErrNoSuchAsset       = errors.New(`No such asset with the given checksum`)
	ErrNoUpdateAvailable = errors.New(`No update available`)
)
