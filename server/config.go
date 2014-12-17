package server

type ServerConfig struct {
	Country        string // 2 letter country code
	Portmap        int
	AdvertisedHost string // FQDN that is guaranteed to hit this server
	WaddellAddr    string // Address at which to connect to waddell for signaling
}
