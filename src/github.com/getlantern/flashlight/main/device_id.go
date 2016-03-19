package main

import (
	"crypto/rand"
)

const deviceIDSize = 80

var (
	deviceIDCharset = `0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ`
)

func NewDeviceID() string {
	buf := make([]byte, deviceIDSize)
	rand.Read(buf)

	lr := uint(len(deviceIDCharset))

	for i := uint(0); i < deviceIDSize; i++ {
		buf[i] = deviceIDCharset[buf[i]%byte(lr)]
	}

	return string(buf)
}
