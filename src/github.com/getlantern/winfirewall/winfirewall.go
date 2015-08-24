package winfirewall

// +build windows

/*
#cgo CFLAGS: -DCINTERFACE -DCOBJMACROS -I. -std=c99
#cgo LDFLAGS: -lole32 -loleaut32 -L. -lhnetcfg

#include "winfirewall.h"
*/
import "C"

import (
	"unsafe"
)

type Firewall struct {
	policy unsafe.Pointer
}

func cBool(goBool bool) C.BOOL {
	if goBool {
		return C.BOOL(1)
	} else {
		return C.BOOL(0)
	}
}

func hresultToString(hr C.HRESULT) {
}

func NewFirewallPolicy(asAdmin bool) (*Firewall, error) {
	var policy unsafe.Pointer
	C.windows_firewall_initialize(&policy, cBool(asAdmin))
	return &Firewall{policy: policy}, nil
}
