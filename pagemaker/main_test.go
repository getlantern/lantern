package main

import (
	"testing"

	"github.com/stretchr/testify/require"
)

func TestReadUnmarshalFile(t *testing.T) {
	var sites sites
	err := readUnmarshalFile("social.yml", &sites)
	require.NoError(t, err)
	require.NotNil(t, sites)
	t.Logf("%v sites found: %+v", len(sites), sites)
}

func TestParseJSON(t *testing.T) {
	var translations translations
	err := readUnmarshalFile("translations/en.json", &translations)
	require.NoError(t, err)
	require.NotNil(t, translations)
	t.Logf("translations parsed: %+v", translations)
}
