// Package utils provides internal utilities
package utils

import (
	"math/rand"
	"os"
	"time"
)

func init() {
	rand.Seed(time.Now().UTC().UnixNano())
}

func GetTestKey() string {
	key := os.Getenv("STRIPE_KEY")

	if len(key) == 0 {
		panic("STRIPE_KEY environment variable is not set, but is needed to run tests!\n")
	}

	return key
}

// h/t: http://stackoverflow.com/questions/22892120/how-to-generate-a-random-string-of-a-fixed-length-in-golang
func RandSeq(n int) string {
	letters := []rune("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")

	b := make([]rune, n)
	for i := range b {
		b[i] = letters[rand.Intn(len(letters))]
	}
	return string(b)
}
