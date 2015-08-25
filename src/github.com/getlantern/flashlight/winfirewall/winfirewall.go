package winfirewall

import (
	"github.com/getlantern/golog"
	"github.com/getlantern/winfirewall"
)

var (
	log = golog.LoggerFor("flashlight.winfirewall")

	fwRule = &winfirewall.FirewallRule{
		Name:        "Lantern Outbound Traffic",
		Description: "Allow outbound traffic from Lantern",
		Group:       "Internet Access",
		// TODO!!!!
		Application: "C:\\WINDOWS\\explorer.exe",
		Outbound:    true,
	}
)

// IsWindowsFirewallConfigured checks whether the Windows firewall is ready
// to use Lantern.
func IsWindowsFirewallConfigured() (ok bool) {
	fw, err := winfirewall.NewFirewallPolicy(false)
	if err != nil {
		log.Errorf("Error creating Windows firewall policy: %v", err)
		return false
	}
	var isOn bool
	if isOn, err = fw.IsOn(); err != nil {
		log.Errorf("Error querying Windows firewall: %v", err)
		return false
	}
	// If the Firewall is Off, we can consider it configured
	if !isOn {
		return true
	}
	// Otherwise try to find the Lantern rule
	if ok, err = fw.RuleExists(fwRule); err != nil {
		log.Errorf("Error searching Windows firewall rule: %v", err)
		return false
	}
	return
}

func ConfigureWindowsFirewall() {
	// We need to escalate privileges if we want to configure the firewall
	fw, err := winfirewall.NewFirewallPolicy(true)
	if err != nil {
		log.Errorf("Error creating Windows firewall policy: %v", err)
	}
	if err = fw.SetRule(fwRule); err != nil {
		log.Errorf("Error configuring Windows firewall policy: %v", err)
	}
}
