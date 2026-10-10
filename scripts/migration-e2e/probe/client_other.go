//go:build !windows

package main

import "errors"

func newPlatformClient() (serviceClient, error) {
	return nil, errors.New("unsupported platform")
}
