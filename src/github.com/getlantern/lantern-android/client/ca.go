package client

// ca represents a certificate authority
type ca struct {
	CommonName string
	Cert       string // PEM-encoded
}
