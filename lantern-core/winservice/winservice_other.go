//go:build !windows

package winservice

import "context"

// Query returns ErrUnsupported off Windows.
func Query() (Status, error) { return Status{}, ErrUnsupported }

// Repair returns ErrUnsupported off Windows.
func Repair(context.Context) error { return ErrUnsupported }
