package util

import (
	"crypto/sha256"
	"encoding/hex"
	"io"
	"os"
)

// GetFileHash returns the hex encoding of the sha-256 hash of the
// file at the specified path.
func GetFileHash(path string) (string, error) {
	log.Debugf("Hashing file at path %v", path)
	if f, err := os.Open(path); err != nil {
		log.Errorf("test %v", err)
		return "", err
	} else {
		defer f.Close()
		hasher := sha256.New()
		if _, e := io.Copy(hasher, f); e != nil {
			log.Error(e)
			return "", e
		} else {
			sum := hasher.Sum(nil)
			return hex.EncodeToString(sum), nil
		}
	}
}
