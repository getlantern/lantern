package winfirewall

import "unsafe"

// FirewallPolicy controls
type FirewallPolicy struct {
	policy  unsafe.Pointer
	asAdmin bool
}

type FirewallRule struct {
	Name        string
	Description string
	Group       string
	Application string
	Port        string
	Outbound    bool
}
