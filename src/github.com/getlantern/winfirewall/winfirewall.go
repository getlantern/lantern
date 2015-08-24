package main

// +build windows

/*
#cgo CFLAGS: -DCINTERFACE -DCOBJMACROS -I. -std=c99
#cgo LDFLAGS: -lole32 -loleaut32 -L. -lhnetcfg

#include "winfirewall.h"
*/
import "C"

import (
	"errors"
	"fmt"
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

func hresultToGoError(hr C.HRESULT) error {
	var cStr *C.char = C.hr_to_string(hr)
	defer C.free(unsafe.Pointer(cStr))
	return errors.New(C.GoString(cStr))
}

func NewFirewallPolicy(asAdmin bool) (*Firewall, error) {
	var policy unsafe.Pointer
	hr := C.windows_firewall_initialize(&policy, cBool(asAdmin))
	return &Firewall{policy: policy}, hresultToGoError(hr)
}

func main() {
	fw, err := NewFirewallPolicy(false)
	if err != nil {
		fmt.Printf("Error creating firewall policy: %v", err)
	}
	fmt.Println(fw)
}
