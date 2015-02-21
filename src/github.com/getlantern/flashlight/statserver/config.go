package statserver

// Config holds configuration values that are relevant to the statserver
// package.
type Config struct {
	ProxyAddr     string
	CloudConfigCA string
}

// Pointer to configuration.
var cfg *Config

// Configure copies configuration updates into the cfg variable.
func Configure(updated *Config) error {
	cfg = updated
	return nil
}
