package main

import (
	"path"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestReadUnmarshalFile(t *testing.T) {
	var sites sites
	err := readUnmarshalFile(linksFile, &sites)
	require.NoError(t, err)
	require.NotNil(t, sites)
	t.Logf("%v sites found: %+v", len(sites), sites)
}

func TestParseJSON(t *testing.T) {
	var common translations
	filePath := path.Join(translationsDir, "common.json")
	err := readUnmarshalFile(filePath, &common)
	require.NoError(t, err)
	require.NotNil(t, common)
	t.Logf("file parsed: %+v", common)
}

func TestLoadInfo(t *testing.T) {
	filePath := path.Join(translationsDir, "en.json")
	info, err := loadInfo(filePath)
	require.NoError(t, err)
	require.NotNil(t, info)
	t.Logf("info.Translations: %+v\n", info.Translations)
	t.Logf("info.Common: %+v\n", info.Common)
	t.Logf("info.Releases: %+v\n", info.Releases)
	t.Logf("info.Sites: %+v\n", info.Sites)
}
