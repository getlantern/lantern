package resolver

import (
	"crypto/rand"
	"errors"
	"math/big"
	"net"
	"time"

	"github.com/getlantern/golog"
	"github.com/miekg/dns"
)

var (
	log = golog.LoggerFor("lantern-android.resolver")
)

type record struct {
	IP  net.IP
	ttl time.Duration
}

type DnsResponse struct {
	records []record
}

func (response *DnsResponse) PickRandomIP() (net.IP, error) {
	length := int64(len(response.records))
	if length < 1 {
		return nil, errors.New("no IP address")
	}

	index, err := rand.Int(rand.Reader, big.NewInt(length))
	if err != nil {
		return nil, err
	}

	record := response.records[index.Int64()]
	return record.IP, nil
}

func ResolveIP(addr string, conn net.Conn) (*DnsResponse, error) {

	dnsResponse := &DnsResponse{
		records: make([]record, 0),
	}

	// Send the DNS query
	dnsConn := &dns.Conn{Conn: conn}
	defer dnsConn.Close()
	query := new(dns.Msg)
	query.SetQuestion(dns.Fqdn(addr), dns.TypeA)
	query.RecursionDesired = true
	dnsConn.WriteMsg(query)

	// Process the response
	response, err := dnsConn.ReadMsg()
	if err != nil {
		return nil, err
	}
	for _, answer := range response.Answer {
		if a, ok := answer.(*dns.A); ok {
			dnsResponse.records = append(dnsResponse.records,
				record{
					IP:  a.A,
					ttl: time.Duration(a.Hdr.Ttl) * time.Second,
				})
		}
	}
	return dnsResponse, nil
}
