package server

type ServerConfig struct {
	// Unencrypted: Whether or not to run in unencrypted mode (no TLS)
	Unencrypted bool

	// Country: 2 letter country code
	Country string

	// RegisterAt: URL at which to register this server as available
	RegisterAt string

	// Portmap: if non-zero, server will attempt to map this port on the UPnP or
	// NAT-PMP internet gateway device
	Portmap int

	// FrontFQDNs: map each fronting provider to the FQDN with which this
	// server is registered in it
	FrontFQDNs map[string]string

	// WaddellAddr: Address at which to connect to waddell for signaling
	WaddellAddr string
}
