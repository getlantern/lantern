package server

type ServerConfig struct {
	// Unencrypted: Whether or not to run in unencrypted mode (no TLS)
	Unencrypted bool

	// Country: 2 letter country code
	Country string

	// Portmap: if non-zero, server will attempt to map this port on the UPnP or
	// NAT-PMP internet gateway device
	Portmap int

	// AdvertisedHost: FQDN that is guaranteed to hit this server
	AdvertisedHost string

	// WaddellAddr: Address at which to connect to waddell for signaling
	WaddellAddr string
}
