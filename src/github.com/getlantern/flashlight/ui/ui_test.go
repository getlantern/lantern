package ui

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestProAddr(t *testing.T) {
	addr := "127.1.1.1:4830"
	proAddr := proProxyAddr(addr)
	assert.Equal(t, "127.1.1.1:1233", proAddr)
}
