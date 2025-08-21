//go:build windows

package wintunmgr

import (
	"crypto/rand"
	"encoding/hex"
	"time"
)

func shortGUID(s string) string {
	if len(s) <= 8 {
		return s
	}
	return s[:8]
}

func sinceMs(t time.Time) int64 { return time.Since(t).Milliseconds() }

func randID(prefix string, n int) string {
	if n <= 0 {
		n = 8
	}
	b := make([]byte, n)
	_, _ = rand.Read(b)
	return prefix + hex.EncodeToString(b)
}
