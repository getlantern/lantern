//go:build !android && !ios && !macos

package main

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestWaitForDaemon(t *testing.T) {
	down := errors.New("IPC not running")

	t.Run("returns once lanternd answers", func(t *testing.T) {
		calls := 0
		err := waitForDaemon(context.Background(), func() error {
			calls++
			if calls < 3 {
				return down
			}
			return nil
		}, time.Millisecond)
		require.NoError(t, err)
		assert.Equal(t, 3, calls)
	})

	t.Run("gives up when ctx ends, keeping the last error", func(t *testing.T) {
		ctx, cancel := context.WithTimeout(context.Background(), 20*time.Millisecond)
		defer cancel()
		err := waitForDaemon(ctx, func() error { return down }, time.Millisecond)
		assert.ErrorIs(t, err, context.DeadlineExceeded)
		assert.ErrorIs(t, err, down)
	})
}
