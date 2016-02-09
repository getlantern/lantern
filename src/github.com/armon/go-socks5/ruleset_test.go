package socks5

import "testing"

func TestPermitCommand(t *testing.T) {
	r := &PermitCommand{true, false, false}

	if !r.Allow(&Request{Command: ConnectCommand}) {
		t.Fatalf("expect connect")
	}

	if r.Allow(&Request{Command: BindCommand}) {
		t.Fatalf("do not expect bind")
	}

	if r.Allow(&Request{Command: AssociateCommand}) {
		t.Fatalf("do not expect associate")
	}
}
