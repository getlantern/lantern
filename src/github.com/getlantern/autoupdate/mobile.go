package autoupdate

import (
	"bytes"
	"compress/bzip2"
	"io"
	"io/ioutil"
	"net/http"
	"os"

	"github.com/blang/semver"
	"github.com/getlantern/flashlight/proxied"
	"github.com/getlantern/go-update"
)

type Updater interface {
	// PublishProgress: publish percentage of update already downloaded
	PublishProgress(int)
}

// byteCounter wraps an existing io.Reader and keeps track of the byte
// count while downloading the latest update
type byteCounter struct {
	io.Reader // Underlying io.Reader to track bytes transferred
	Updater
	total    int64   // Total bytes transferred
	length   int64   // Expected length
	progress float64 // How much of the update has been downloaded
}

func (pt *byteCounter) Read(p []byte) (int, error) {
	n, err := pt.Reader.Read(p)
	if n > 0 {
		pt.total += int64(n)
		percentage := float64(pt.total) / float64(pt.length) * float64(100)
		pt.Updater.PublishProgress(int(percentage))
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

	if res == nil {
		log.Debugf("No new version available!")
		return "", nil
	}

	v, err := semver.Make(version)
	if err != nil {
		log.Errorf("Error checking for update; could not parse version number: %v", err)
		return "", err
	}

	if isNewerVersion(v, res.Version) {
		log.Debugf("Newer version of Lantern mobile available! %s at %s", res.Version, res.Url)
		return res.Url, nil
	}

	return "", nil
}

// CheckMobileUpdate checks if a new update is available for mobile.
func CheckMobileUpdate(shouldProxy bool, updateServer, appVersion string) (string, error) {
	return doCheckUpdate(shouldProxy, appVersion,
		updateServer, []byte(PackagePublicKey))
}

// UpdateMobile downloads the latest APK from the given url to file apkPath.
// - if shouldProxy is true, the client proxies through the given HTTP proxy
func UpdateMobile(shouldProxy bool, url, apkPath string, updater Updater) error {
	out, err := os.Create(apkPath)
	if err != nil {
		log.Error(err)
		return err
	}
	defer out.Close()
	return doUpdateMobile(shouldProxy, url, out, updater)
}

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
