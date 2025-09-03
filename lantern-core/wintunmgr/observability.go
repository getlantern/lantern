//go:build windows

package wintunmgr

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"runtime/debug"
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

func recoverErr(where string, perr *error) {
	if r := recover(); r != nil {
		slog.Errorf("panic: %s r=%v\n%s", where, r, debug.Stack())
		if perr != nil && *perr == nil {
			*perr = fmt.Errorf("panic in %s: %v", where, r)
		}
	}
}
