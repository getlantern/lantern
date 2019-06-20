package socks5

import (
	"testing"
)

func TestDNSResolver(t *testing.T) {
	d := DNSResolver{}

	addr, err := d.Resolve("localhost")
	if err != nil {
		t.Fatalf("err: %v", err)
	}

	if !addr.IsLoopback() {
		t.Fatalf("expected loopback")
	}
}
