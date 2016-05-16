package autoupdate

import (
	"bytes"
	"compress/bzip2"
	"io"
	"io/ioutil"
	"net/http"
	"os"

	"github.com/blang/semver"
	"github.com/getlantern/flashlight/config"
	"github.com/getlantern/flashlight/proxied"
	"github.com/getlantern/go-update"
)

var (
	updateServer = config.DefaultUpdateServerURL
	//updateServer = "https://update-stage.getlantern.org/update"
)

type Updater interface {
	SetProgress(int)
}

// byteCounter wraps an existing io.Reader.
type byteCounter struct {
	io.Reader // Underlying io.Reader to track bytes transferred
	Updater
	total    int64   // Total bytes transferred
	length   int64   // Expected length
	progress float64 // How much of the update has been downloaded
}

// Read 'overrides' the underlying io.Reader's Read method.
// This is the one that will be called by io.Copy(). We simply
// use it to keep track of byte counts and then forward the call.
func (pt *byteCounter) Read(p []byte) (int, error) {
	n, err := pt.Reader.Read(p)
	if n > 0 {
		pt.total += int64(n)
		percentage := float64(pt.total) / float64(pt.length) * float64(100)
		pt.Updater.SetProgress(int(percentage))
	}
	return n, err
}

func doCheckUpdate(shouldProxy bool, version, URL string, publicKey []byte) (string, error) {

	log.Debugf("Checking for new mobile version; current version: %s", version)

	httpClient, err := proxied.GetHTTPClient(shouldProxy)
	if err != nil {
		log.Errorf("Could not get HTTP client to download update: %v", err)
		return "", err
	}

	// specify go-update should use our httpClient
	update.SetHttpClient(httpClient)

	res, err := checkUpdate(version, URL, publicKey)
	if err != nil {
		log.Errorf("Error checking for update for mobile: %v", err)
		return "", err
	}

	v, err := semver.Make(version)
	if err != nil {
		log.Errorf("Error checking for update; could not parse version number: %v", err)
		return "", err
	}

	if res == nil {
		log.Debugf("No new version available!")
		return "", nil

	}

	if isNewerVersion(v, res.Version) {
		log.Debugf("Newer version of Lantern mobile available! %s at %s", res.Version, res.Url)
		return res.Url, nil
	}

	return "", nil
}

// CheckMobileUpdate checks if a new update is available for mobile.
func CheckMobileUpdate(shouldProxy bool, appVersion string) (string, error) {
	return doCheckUpdate(shouldProxy, appVersion,
		updateServer, []byte(PackagePublicKey))
}

// UpdateMobile downloads the latest APK from the given url to apkPath
// - if shouldProxy is true, the client proxies through the given HTTP proxy
// Updater is an interface for calling back to Java (whether to display download progress
// or show an error message)
func UpdateMobile(shouldProxy bool, url, apkPath string, updater Updater) error {

	out, err := os.Create(apkPath)
	if err != nil {
		log.Error(err)
		return err
	}
	defer out.Close()

	return doUpdateMobile(shouldProxy, url, out, updater)
}

// UpdateMobile downloads the latest APK from the given url to apkPath
// - if shouldProxy is true, the client proxies through the given HTTP proxy
// Updater is an interface for calling back to Java (whether to display download progress
// or show an error message)
func doUpdateMobile(shouldProxy bool, url string, out *os.File, updater Updater) error {
	var req *http.Request
	var res *http.Response

	log.Debugf("Attempting to download APK from %s", url)

	httpClient, err := proxied.GetHTTPClient(shouldProxy)
	if err != nil {
		log.Error(err)
		return err
	}

	if req, err = http.NewRequest("GET", url, nil); err != nil {
		log.Errorf("Error downloading update: %v", err)
		return err
	}

	// ask for gzipped feed content
	req.Header.Add("Accept-Encoding", "gzip")

	if res, err = httpClient.Do(req); err != nil {
		log.Errorf("Error requesting update: %v", err)
		return err
	}

	defer res.Body.Close()

	// We use a special byteCounter that storres a reference
	// to the updater interface to make it easy to publish progress
	// for how much of the update has been downloaded already.
	bytespt := &byteCounter{Updater: updater,
		Reader: res.Body, length: res.ContentLength}

	contents, err := ioutil.ReadAll(bytespt)
	if err != nil {
		log.Errorf("Error reading update: %v", err)
		return err
	}

	_, err = io.Copy(out, bzip2.NewReader(bytes.NewReader(contents)))
	if err != nil {
		log.Errorf("Error copying update: %v", err)
		return err
	}

	return nil
}
