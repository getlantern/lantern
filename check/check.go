package check

import (
	"bitbucket.org/kardianos/osext"
	"bytes"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"github.com/inconshreveable/go-update"
	"io/ioutil"
	"net/http"
	"runtime"
)

type Initiative string

const (
	INITIATIVE_NEVER  = "never"
	INITIATIVE_AUTO   = "auto"
	INITIATIVE_MANUAL = "manual"
)

var NoUpdateAvailable error = fmt.Errorf("No update available")

type Params struct {
	// protocol version
	Version int `json:"version"`
	// identifier of the application to update
	AppId string `json:"app_id"`
	// version of the application updating itself
	AppVersion string `json:"app_version"`
	// operating system of target platform
	OS string `json:"-"`
	// hardware architecture of target platform
	Arch string `json:"-"`
	// application-level user identifier
	UserId string `json:"user_id"`
	// checksum of the binary to replace (used for returning diff patches)
	Checksum string `json:"checksum"`
	// tags for custom update channels
	Tags map[string]string `json:"tags"`
}

type Result struct {
	Initiative Initiative
	Url        string           // url where to download the updated application
	PatchUrl   string           // a URL to a patch to apply
	PatchType  update.PatchType // the patch format (only bsdiff supported at the moment)
	Version    string           // version of the new application
	Checksum   string           // expected checksum of the new application
	Signature  string           // signature for verifying update authenticity
}

// CheckForUpdate makes an HTTP post to a URL with the JSON serialized
// representation of Params. It returns the deserialized result object
// returned by the remote endpoint or an error. If you do not set
// OS/Arch, CheckForUpdate will populate them for you. Similarly, if
// Version is 0, it will be set to 1. Lastly, if Checksum is the empty
// string, it will be automatically be computed for the running program's
// executable file.
func (p *Params) CheckForUpdate(url string) (*Result, error) {
	if p.OS == "" {
		p.OS = runtime.GOOS
	}

	if p.Arch == "" {
		p.Arch = runtime.GOARCH
	}

	if p.Version == 0 {
		p.Version = 1
	}

	// ignore errors auto-populating the checksum
	// if it fails, you just won't be able to patch
	if p.Checksum == "" {
		p.Checksum = defaultChecksum()
	}

	p.Tags["os"] = p.OS
	p.Tags["arch"] = p.Arch

	body, err := json.Marshal(p)
	if err != nil {
		return nil, err
	}

	resp, err := http.Post(url, "application/json", bytes.NewReader(body))
	if err != nil {
		return nil, err
	}

	// no content means no available update
	if resp.StatusCode == 204 {
		return nil, NoUpdateAvailable
	}

	defer resp.Body.Close()
	respBytes, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	result := new(Result)
	if err := json.Unmarshal(respBytes, result); err != nil {
		return nil, err
	}

	return result, nil
}

func (p *Params) CheckAndApplyUpdate(url string, u *update.Update) (result *Result, err error, errRecover error) {
	// check for an update
	result, err = p.CheckForUpdate(url)
	if err != nil {
		return
	}

	// run the update if one is available and the server says it's auto
	if result.Update != nil && result.Initiative == INITIATIVE_AUTO {
		err, errRecover = result.Update(u)
	}

	return
}

func (r *Result) Update(u *update.Update) (err error, errRecover error) {
	if r.Checksum != "" {
		u.Checksum, err = hex.DecodeString(r.Checksum)
		if err != nil {
			return
		}
	}

	if r.Signature != "" {
		u.Signature, err = hex.DecodeString(r.Signature)
		if err != nil {
			return
		}
	}

	if r.PatchType != "" {
		u.PatchType = r.PatchType
	}

	if r.Url == "" && r.PatchUrl == "" {
		err = fmt.Errorf("Result does not contain an update url or patch update url")
		return
	}

	if r.PatchUrl != "" {
		err, errRecover = u.FromUrl(r.PatchUrl)
		if err == nil {
			// success!
			return
		} else {
			// failed to update from patch URL, try with the whole thing
			if r.Url == "" || errRecover != nil {
				// we can't try updating from a URL with the full contents
				// in these cases, so fail
				return
			} else {
				u.PatchType = update.PATCHTYPE_NONE
			}
		}
	}

	// try updating from a URL with the full contents
	return u.FromUrl(r.Url)
}

func defaultChecksum() string {
	path, err := osext.Executable()
	if err != nil {
		return ""
	}

	checksum, err := update.ChecksumForFile(path)
	if err != nil {
		return ""
	}

	return hex.EncodeToString(checksum)
}
