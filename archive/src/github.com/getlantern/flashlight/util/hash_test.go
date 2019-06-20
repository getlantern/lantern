package util

import (
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestGetFileHash(t *testing.T) {
	wd, _ := os.Getwd()
	path := wd + "/hash.go"

	hash, _ := GetFileHash(path)
	//log.Debugf("Got hash! %x", hash)
	log.Debugf("Got hash! %v", hash)

	// Update this with shasum -a 256 hash.go
	assert.Equal(t, "699b8a31a9c8c0b26ce1b4cbe79af1de97de9ef83b9ab717241ed53fb5d86df2", hash,
		"hashes not equal! has hashes.go changed?")
}
