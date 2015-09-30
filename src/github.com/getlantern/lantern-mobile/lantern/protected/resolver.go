package protected

import (
	"crypto/rand"
	"errors"
	"math/big"
	"net"
	"time"

	"github.com/miekg/dns"
)

type record struct {
	IP  net.IP
	ttl time.Duration
}

type DnsResponse struct {
	records []record
}

// PickRandomIP picks a random IP address from a DNS response
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

// dnsLookup is used whenever we need to conduct a DNS query over a given TCP connection
func dnsLookup(addr string, conn net.Conn) (*DnsResponse, error) {

	log.Debugf("Doing a DNS lookup on %s", addr)

	dnsResponse := &DnsResponse{
		records: make([]record, 0),
	}

	// create the connection to the DNS server
	dnsConn := &dns.Conn{Conn: conn}
	defer dnsConn.Close()

	m := new(dns.Msg)
	m.Id = dns.Id()
	// set the question section in the dns query
	// Fqdn returns the fully qualified domain name
	m.SetQuestion(dns.Fqdn(addr), dns.TypeA)
	m.RecursionDesired = true

	dnsConn.WriteMsg(m)

	response, err := dnsConn.ReadMsg()
	if err != nil {
		log.Errorf("Could not process DNS response: %v", err)
		return nil, err
	}

	// iterate over RRs containing the DNS answer
	for _, answer := range response.Answer {
		if a, ok := answer.(*dns.A); ok {
			// append the result to our list of records
			// the A records in the RDATA section of the DNS answer
			// contains the actual IP address
			dnsResponse.records = append(dnsResponse.records,
				record{
					IP:  a.A,
					ttl: time.Duration(a.Hdr.Ttl) * time.Second,
				})
		}
	}
	return dnsResponse, nil
}
