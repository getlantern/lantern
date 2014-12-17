package igdman

import (
	"bytes"
	"fmt"
	"io"
	"os/exec"
	"strings"
	"sync"
	"time"

	"github.com/getlantern/byteexec"
	"github.com/getlantern/withtimeout"
)

const (
	IGD_URL_LABEL             = "Found valid IGD : "
	LOCAL_IP_ADDRESS_LABEL    = "Local LAN ip address : "
	EXTERNAL_IP_ADDRESS_LABEL = "ExternalIPAddress = "
)

var (
	upnpcbe *byteexec.Exec
)

func init() {
	upnpcBytes, err := Asset("upnpc")
	if err != nil {
		panic(fmt.Errorf("Unable to read upnpc bytes: %s", err))
	}

	upnpcbe, err = byteexec.New(upnpcBytes, "upnpc")
	if err != nil {
		panic(fmt.Errorf("Unable to construct byteexec for upnpc: %s", err))
	}
}

type upnpIGD struct {
	igdUrl            string
	internalIP        string
	externalIP        string
	updateStatusMutex sync.Mutex
}

func NewUpnpIGD() (igd *upnpIGD, err error) {
	igd = &upnpIGD{}
	err = igd.updateStatus()
	return
}

func (igd *upnpIGD) GetExternalIP() (ip string, err error) {
	err = igd.updateStatusIfNecessary()
	if err != nil {
		return "", err
	}
	return igd.externalIP, nil
}

func (igd *upnpIGD) AddPortMapping(proto protocol, internalIP string, internalPort int, externalPort int, expiration time.Duration) error {
	if err := igd.updateStatusIfNecessary(); err != nil {
		return fmt.Errorf("Unable to add port mapping: %s", err)
	}
	params := []string{
		"-url", igd.igdUrl,
		"-a", internalIP, fmt.Sprintf("%d", internalPort), fmt.Sprintf("%d", externalPort), string(proto),
	}
	if expiration > 0 {
		params = append(params, fmt.Sprintf("%d", expiration/time.Second))
	}
	out, err := upnpcbe.Command(params...).CombinedOutput()
	if err != nil {
		return fmt.Errorf("Unable to add port mapping: %s\n%s", err, out)
	} else if strings.Contains(string(out), "failed with") {
		return fmt.Errorf("Unable to add port mapping: \n%s", out)
	} else {
		return nil
	}
}

func (igd *upnpIGD) RemovePortMapping(proto protocol, externalPort int) error {
	if err := igd.updateStatusIfNecessary(); err != nil {
		return fmt.Errorf("Unable to add port mapping: %s", err)
	}
	params := []string{
		"-url", igd.igdUrl,
		"-d", fmt.Sprintf("%d", externalPort), string(proto),
	}
	out, err := execTimeout(opTimeout, upnpcbe.Command(params...))
	if err != nil {
		return fmt.Errorf("Unable to remove port mapping: %s\n%s", err, out)
	} else if !strings.Contains(string(out), "UPNP_DeletePortMapping() returned : 0") {
		return fmt.Errorf("Unable to remove port mapping: \n%s", out)
	} else {
		return nil
	}
}

func (igd *upnpIGD) updateStatusIfNecessary() error {
	igd.updateStatusMutex.Lock()
	defer igd.updateStatusMutex.Unlock()
	if igd.igdUrl == "" {
		return igd.updateStatus()
	}
	return nil
}

// updateStatus updates the IGD's status fields
func (igd *upnpIGD) updateStatus() error {
	skipDiscovery := igd.igdUrl != ""
	params := []string{"-s"}
	if skipDiscovery {
		params = []string{"-url", igd.igdUrl, "-s"} // -s has to be at the end for some reason
	}
	out, err := execTimeout(opTimeout, upnpcbe.Command(params...))
	if err != nil {
		if skipDiscovery {
			// Clear remembered url and try again
			igd.igdUrl = ""
			return igd.updateStatus()
		} else {
			return fmt.Errorf("Unable to call upnpc to get status: %s\n%s", err, out)
		}
	}
	resp := string(out)
	if igd.igdUrl, err = igd.extractFromStatusResponse(resp, IGD_URL_LABEL); err != nil {
		return err
	}
	if igd.internalIP, err = igd.extractFromStatusResponse(resp, LOCAL_IP_ADDRESS_LABEL); err != nil {
		return err
	}
	if igd.externalIP, err = igd.extractFromStatusResponse(resp, EXTERNAL_IP_ADDRESS_LABEL); err != nil {
		return err
	}
	return nil
}

func (igd *upnpIGD) extractFromStatusResponse(resp string, label string) (string, error) {
	i := strings.Index(resp, label)
	if i < 0 {
		return "", fmt.Errorf("%s not available from upnpc", label)
	}
	resp = resp[i+len(label):]
	// Look for either carriage return (windows) or line feed (unix)
	sr := strings.Index(resp, "\r")
	sn := strings.Index(resp, "\n")
	s := sr
	if sr < 0 {
		s = sn
	}
	if s < 0 {
		return "", fmt.Errorf("Unable to find newline after %s", label)
	}
	return resp[:s], nil
}

func execTimeout(timeout time.Duration, cmd *exec.Cmd) ([]byte, error) {
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return nil, err
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return nil, err
	}
	err = cmd.Start()
	if err != nil {
		return nil, err
	}

	b := bytes.NewBuffer([]byte{})
	go io.Copy(b, stdout)
	go io.Copy(b, stderr)

	_, timedOut, err := withtimeout.Do(timeout, func() (interface{}, error) {
		return nil, cmd.Wait()
	})
	if err != nil {
		if timedOut {
			go cmd.Process.Kill()
		}
		return nil, err
	}
	return b.Bytes(), nil
}
