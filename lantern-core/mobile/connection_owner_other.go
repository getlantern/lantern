//go:build !darwin

package mobile

import (
	"errors"

	"github.com/sagernet/sing-box/experimental/libbox"
)

var errConnectionOwnerUnsupported = errors.New("connection owner lookup is not supported on this platform")

var findConnectionOwner = func(
	_ int32,
	_ string,
	_ int32,
	_ string,
	_ int32,
) (*libbox.ConnectionOwner, error) {
	return nil, errConnectionOwnerUnsupported
}
