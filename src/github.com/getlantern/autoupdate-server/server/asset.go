package server

import (
	"crypto/sha1"
	"fmt"
	"io"
	"net/http"
	"os"
)

const (
	assetsDirectory = "assets/"
)

func init() {
	err := os.MkdirAll(assetsDirectory, os.ModeDir|0700)
	if err != nil {
		log.Fatalf("Could not create directory for storing assets: %q", err)
	}
}

// downloadAsset grabs the contents of the body of the given URL and stores
// then into $ASSETS_DIRECTORY/SHA1($URL).
func downloadAsset(uri string) (localfile string, err error) {
	localfile = assetsDirectory + fmt.Sprintf("%x", sha1.Sum([]byte(uri)))

	if !fileExists(localfile) {
		var res *http.Response

		if res, err = http.Get(uri); err != nil {
			return "", err
		}

		if res.StatusCode != http.StatusOK {
			return "", fmt.Errorf("Expecting 200 OK, got: %s", res.Status)
		}

		var fp *os.File

		if fp, err = os.Create(localfile); err != nil {
			return "", err
		}

		defer fp.Close()

		if _, err = io.Copy(fp, res.Body); err != nil {
			return "", err
		}

	}

	return localfile, nil
}

func assetURL(localfile string) (url string) {
	return localfile
}
