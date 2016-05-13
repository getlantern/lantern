package logging

import (
	"testing"

	"github.com/getlantern/testify/assert"
)

func TestBordaClient(t *testing.T) {
	bc := NewBordaReporter(
		&BordaReporterOptions{
			MaxChunkSize: 5,
		})

	assert.NotNil(t, bc)
}
