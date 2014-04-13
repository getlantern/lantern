package check

import (
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
	INITIATIVE_NOUPDATE = "noupdate"
	INITIATIVE_AUTO     = "auto"
	INITIATIVE_MANUAL   = "manual"
)

type Params struct {
	Version    int               // protocol version
	AppId      string            // identifier of the application to update
	AppVersion string            // version of the application updating itself
	OS         string            // operating system of target platform
	Arch       string            // hardware architecture of target platform
	UserId     string            // application-level user identifier
	Channel    string            // override the server settings and request an update from a specific channel
	Checksum   string            // checksum of the binary to replace (used for returning diff patches)
	Extra      map[string]string // extra fields for custom behaviors
}

type Result struct {
	Initiative Initiative
	AppId      string           // identifier of the application to update
	Url        string           // url where to download the updated application
	PatchUrl   string           // a URL to a patch to apply
	PatchType  update.PatchType // the patch format (only bsdiff supported at the moment)
	OS         string           // target operating system of the new application
	Arch       string           // target hardware architecture of the new application
	Version    string           // version of the new application
	Checksum   string           // expected checksum of the new application
	Signature  string           // signature for verifying update authenticity
}

// CheckForUpdate will auto-populate the OS/Arch params if not set
func (p *Params) CheckForUpdate(url string) (*Result, error) {
	if p.OS == "" {
		p.OS = runtime.GOOS
	}

	if p.Arch == "" {
		p.Arch = runtime.GOARCH
	}

	body, err := json.Marshal(p)
	if err != nil {
		return nil, err
	}

	resp, err := http.Post(url, "application/json", bytes.NewReader(body))
	if err != nil {
		return nil, err
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

func (p *Params) CheckAndApplyUpdate(url string, u *update.Update, progress chan int) (result *Result, err error, errRecover error) {
	// check for an update
	result, err = p.CheckForUpdate(url)
	if err != nil {
		return
	}

	// run the update if one is available and the server says it's auto
	if result.Update != nil && result.Initiative == INITIATIVE_AUTO {
		err, errRecover = result.Update(u, progress)
	}

	return
}

func (r *Result) Update(u *update.Update, progress chan int) (err error, errRecover error) {
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
				// the progress channel will be closed from the first attempt
				// use a dummy replacement
				u.PatchType = update.PATCHTYPE_NONE
				progress = make(chan int)
			}
		}
	}

	// try updating from a URL with the full contents
	return u.FromUrl(r.Url)
}
