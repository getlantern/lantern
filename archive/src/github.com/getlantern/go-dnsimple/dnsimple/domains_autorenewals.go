package dnsimple

import (
	"fmt"
)

// EnableAutoRenewal enables the auto-renewal feature for the domain.
//
// DNSimple API docs: http://developer.dnsimple.com/domains/autorenewal/#enable
func (s *DomainsService) EnableAutoRenewal(domain interface{}) (*Response, error) {
	path := fmt.Sprintf("%s/auto_renewal", domainPath(domain))

	res, err := s.client.post(path, nil, nil)
	if err != nil {
		return res, err
	}

	return res, nil
}

// DisableAutoRenewal disables the auto-renewal feature for the domain.
//
// DNSimple API docs: http://developer.dnsimple.com/domains/autorenewal/#disable
func (s *DomainsService) DisableAutoRenewal(domain interface{}) (*Response, error) {
	path := fmt.Sprintf("%s/auto_renewal", domainPath(domain))

	res, err := s.client.delete(path, nil)
	if err != nil {
		return res, err
	}

	return res, nil
}

// SetAutoRenewal is a convenient helper to enable/disable the auto-renewal feature for the domain.
//
// DNSimple API docs: http://developer.dnsimple.com/domains/autorenewal/#enable
// DNSimple API docs: http://developer.dnsimple.com/domains/autorenewal/#disable
func (s *DomainsService) SetAutoRenewal(domain interface{}, autoRenew bool) (*Response, error) {
	if autoRenew {
		return s.EnableAutoRenewal(domain)
	} else {
		return s.DisableAutoRenewal(domain)
	}
}
