package winfirewall

// +build windows

/*
#cgo CFLAGS: -DCINTERFACE -DCOBJMACROS -I. -std=c99
#cgo LDFLAGS: -lole32 -loleaut32 -L. -lhnetcfg

#include "winfirewall.h"
*/
import "C"

import (
	"errors"
	"unsafe"
)

type FirewallPolicy struct {
	policy unsafe.Pointer
}

type FirewallRule struct {
	Name        string
	Description string
	Group       string
	Application string
	Port        string
	Outbound    bool
}

// NewFirewallPolicy creates a new instance of a Firewall Policy controller
// The only argument is a boolean that will prompt the user to escalate privileges.
func NewFirewallPolicy(asAdmin bool) (*FirewallPolicy, error) {
	var policy unsafe.Pointer
	hr := C.windows_firewall_initialize(&policy, cBool(asAdmin))
	return &FirewallPolicy{policy: policy}, hresultToGoError(hr)
}

// Cleanup will deallocate and shutdown the COM interface
func (fw *FirewallPolicy) Cleanup() {
	C.windows_firewall_cleanup(fw.policy)
}

// IsOn returns the current state of the Firewall
func (fw *FirewallPolicy) IsOn() (bool, error) {
	var isOn C.BOOL
	hr := C.windows_firewall_is_on(fw.policy, &isOn)
	return C.int(isOn) != 0, hresultToGoError(hr)
}

// On will activate the Firewall (requires a priveleged Firewall Policy)
func (fw *FirewallPolicy) On() error {
	return hresultToGoError(C.windows_firewall_turn_on(fw.policy))
}

// On will activate the Firewall (requires a priveleged Firewall Policy)
func (fw *FirewallPolicy) Off() error {
	return hresultToGoError(C.windows_firewall_turn_off(fw.policy))
}

// SetRule will activate the given rule (requires a priveleged Firewall Policy)
func (fw *FirewallPolicy) SetRule(fwr *FirewallRule) error {
	cFwRule := cFirewallRule(fwr)
	defer freeCFw(cFwRule)
	return hresultToGoError(C.windows_firewall_rule_set(fw.policy, cFwRule))
}

// RuleExists returns true if an equal rule is found
func (fw *FirewallPolicy) RuleExists(fwr *FirewallRule) (bool, error) {
	var isOn C.BOOL
	cFwRule := cFirewallRule(fwr)
	defer freeCFw(cFwRule)
	hr := C.windows_firewall_rule_exists(fw.policy, cFirewallRule(fwr), &isOn)
	return C.int(isOn) != 0, hresultToGoError(hr)
}

// RemoveRule removes a rule if an equal one is found
func (fw *FirewallPolicy) RemoveRule(fwr *FirewallRule) error {
	cFwRule := cFirewallRule(fwr)
	defer freeCFw(cFwRule)
	return hresultToGoError(C.windows_firewall_rule_remove(fw.policy, cFwRule))
}

// Helper functions

func cBool(goBool bool) C.BOOL {
	if goBool {
		return C.BOOL(1)
	} else {
		return C.BOOL(0)
	}
}

func cFirewallRule(goFwRule *FirewallRule) *C.firewall_rule_t {
	return &C.firewall_rule_t{
		name:        C.CString(goFwRule.Name),
		description: C.CString(goFwRule.Description),
		group:       C.CString(goFwRule.Group),
		application: C.CString(goFwRule.Application),
		port:        C.CString(goFwRule.Port),
		outbound:    cBool(goFwRule.Outbound),
	}
}

func freeCFw(fwr *C.firewall_rule_t) {
	C.free(unsafe.Pointer(fwr.name))
	C.free(unsafe.Pointer(fwr.description))
	C.free(unsafe.Pointer(fwr.group))
	C.free(unsafe.Pointer(fwr.application))
	C.free(unsafe.Pointer(fwr.port))
	C.free(unsafe.Pointer(fwr))
}

func hresultToGoError(hr C.HRESULT) error {
	if hr == C.S_OK {
		return nil
	}
	var cStr *C.char = C.hr_to_string(hr)
	defer C.free(unsafe.Pointer(cStr))
	return errors.New(C.GoString(cStr))
}
