package fronted

import (
	"time"
)

const (
	NumWorkers = 10 // number of worker goroutines for verifying
)

// CA represents a certificate authority
type CA struct {
	CommonName string
	Cert       string // PEM-encoded
}

// Masquerade contains the data for a single masquerade host, including
// the domain and the root CA.
type Masquerade struct {
	// Domain: the domain to use for domain fronting
	Domain string

	// IpAddress: pre-resolved ip address to use instead of Domain (if
	// available)
	IpAddress string

	// LastVetted: the most recent time at which this Masquerade was vetted
	LastVetted time.Time
}
