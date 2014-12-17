package igdman

import (
	"fmt"
	"math"
	"net"
	"strings"
	"time"

	"github.com/getlantern/withtimeout"
	natpmp "github.com/jackpal/go-nat-pmp"
)

type natpmpIGD struct {
	client *natpmp.Client
}

func NewNATPMPIGD() (igd *natpmpIGD, err error) {
	ip, err := defaultGatewayIp()
	if err != nil {
		return nil, fmt.Errorf("Unable to find default gateway: %s", err)
	}
	return &natpmpIGD{natpmp.NewClient(net.ParseIP(ip))}, nil
}

func (igd *natpmpIGD) GetExternalIP() (ip string, err error) {
	result, _, err := withtimeout.Do(opTimeout, func() (interface{}, error) {
		response, err := igd.client.GetExternalAddress()
		if err != nil {
			return "", fmt.Errorf("Unable to get external address: %s", err)
		}
		ip = net.IPv4(response.ExternalIPAddress[0],
			response.ExternalIPAddress[1],
			response.ExternalIPAddress[2],
			response.ExternalIPAddress[3]).String()
		return ip, err
	})
	return result.(string), err
}

func (igd *natpmpIGD) AddPortMapping(proto protocol, internalIP string, internalPort int, externalPort int, expiration time.Duration) error {
	_, _, err := withtimeout.Do(opTimeout, func() (interface{}, error) {
		expirationInSeconds := int(expiration.Seconds())
		if expirationInSeconds == 0 {
			expirationInSeconds = int(math.MaxInt32)
		}
		result, err := igd.client.AddPortMapping(natpmpProtoFor(proto), internalPort, externalPort, expirationInSeconds)
		if err != nil {
			return nil, fmt.Errorf("Unable to add port mapping: %s", err)
		}
		if int(result.MappedExternalPort) != externalPort {
			igd.RemovePortMapping(proto, externalPort)
			return nil, fmt.Errorf("Mapped port didn't match requested")
		}
		return nil, nil
	})
	return err
}

func (igd *natpmpIGD) RemovePortMapping(proto protocol, externalPort int) error {
	_, _, err := withtimeout.Do(opTimeout, func() (interface{}, error) {
		someInternalPort := 15670 // actual value doesn't matter
		_, err := igd.client.AddPortMapping(natpmpProtoFor(proto), someInternalPort, externalPort, 0)
		if err != nil {
			return nil, fmt.Errorf("Unable to remove port mapping: %s", err)
		}
		return nil, nil
	})
	return err
}

func natpmpProtoFor(proto protocol) string {
	return strings.ToLower(string(proto))
}
