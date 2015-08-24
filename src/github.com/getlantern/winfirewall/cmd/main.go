// Demo program to test the library

package main

import (
	"fmt"

	"github.com/getlantern/winfirewall"
)

func main() {
	// Creating a new (unprivileged) Firewall policy
	fw, err := winfirewall.NewFirewallPolicy(false)
	defer fw.Cleanup()
	if err != nil {
		fmt.Printf("Error creating firewall policy: %v", err)
	}

	// Querying the Firewall
	isOn, err := fw.IsOn()
	if err != nil {
		fmt.Printf("Error reading firewall status: %v", err)
	}
	onStr := map[bool]string{true: "ON", false: "OFF"}
	fmt.Println("Firewall is", onStr[isOn], "-> turning", onStr[!isOn])

	// Creating a new (privileged) Firewall policy
	fw, err = winfirewall.NewFirewallPolicy(true)

	// Switching the Firewall
	if isOn {
		err = fw.Off()
	} else {
		err = fw.On()
	}
	if err != nil {
		fmt.Printf("Error switching firewall status: %v", err)
	}

	// Setting a new Firewall Rule
	fwRule := &winfirewall.FirewallRule{
		Name:        "Lantern Outbound Traffic",
		Description: "Allow outbound traffic from Lantern",
		Group:       "Internet Access",
		Application: "C:\\WINDOWS\\explorer.exe",
		Outbound:    true,
	}

	err = fw.SetRule(fwRule)
	if err != nil {
		fmt.Printf("Error setting rule: %v", err)
	}

	// Checking if the rule exists
	exists, err := fw.RuleExists(fwRule)
	if err != nil {
		fmt.Printf("Error finding rule: %v", err)
	}
	if exists {
		fmt.Println("Lantern rule exists")
	} else {
		fmt.Println("Lantern rule does not exist")
	}

	// Removing the rule
	fw.RemoveRule(fwRule)
	if err != nil {
		fmt.Printf("Error removing rule: %v", err)
	}

	// ...and test that it was properly removed
	exists, err = fw.RuleExists(fwRule)
	if err != nil {
		fmt.Printf("Error finding rule: %v", err)
	}
	if exists {
		fmt.Println("Lantern rule exists")
	} else {
		fmt.Println("Lantern rule does not exist")
	}
}
