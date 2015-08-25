// +build !windows

package winfirewall

func NewFirewallPolicy(asAdmin bool) (*FirewallPolicy, error) {
	firewallPanic()
	return nil, nil
}

func (fw *FirewallPolicy) Cleanup() {
	firewallPanic()
}

func (fw *FirewallPolicy) IsOn() (bool, error) {
	firewallPanic()
	return false, nil
}

func (fw *FirewallPolicy) On() error {
	firewallPanic()
	return nil
}

func (fw *FirewallPolicy) Off() error {
	firewallPanic()
	return nil
}

func (fw *FirewallPolicy) SetRule(fwr *FirewallRule) error {
	firewallPanic()
	return nil
}

func (fw *FirewallPolicy) RuleExists(fwr *FirewallRule) (bool, error) {
	firewallPanic()
	return false, nil
}

func (fw *FirewallPolicy) RemoveRule(fwr *FirewallRule) error {
	firewallPanic()
	return nil
}

func firewallPanic() {
	panic("OS Firewall control is only supported on Windows")
}
