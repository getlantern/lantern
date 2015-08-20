/*
 * Test utility for Windows Firewall COM interface library
 */

#include "winfirewall.h"

#include <stdio.h>

int main(int argc, wchar_t* argv[])
{
        HRESULT hr = S_OK;

        ///
        ///
        /// Windows Vista code

        INetFwPolicy2 *policy = NULL;

        hr = windows_firewall_initialize(&policy);
        if (FAILED(hr)) {
            printf("CoCreateInstance for INetFwPolicy2 failed: 0x%08lx\n", hr);
        }

        BOOL is_on;
        hr = windows_firewall_is_on(policy, &is_on);
        if (FAILED(hr)) {
            printf("Error retrieving Firewall status: 0x%08lx\n", hr);
            goto error;
        }
        if (is_on) {
            printf("Windows Firewall is ON -> Turning OFF\n");
            hr = windows_firewall_turn_off(policy);
        } else {
            printf("Windows Firewall is OFF -> Turning ON\n");
            hr = windows_firewall_turn_on(policy);
        }
        if (FAILED(hr)) {
                printf("Firewall to switch: 0x%08lx\n", hr);
                goto error;
        }

        hr = windows_firewall_rule_set(policy,
                                       "Lantern Outbound Traffic",
                                       "Allow outbound traffic from Lantern",
                                       "Internet Access",
                                       "Lantern.exe",
                                       "",
                                       TRUE);
        if (FAILED(hr)) {
            printf("Error setting Firewall rule: 0x%08lx\n", hr);
            goto error;
        }

        BOOL exists;
        hr = windows_firewall_rule_exists(policy,
                                          "Lantern Outbound Traffic",
                                          &exists);
        if (FAILED(hr)) {
            printf("Error getting Firewall rule: 0x%08lx\n", hr);
            goto error;
        }
        if (exists) {
            printf("Lantern rule exists\n");
        } else {
            printf("Lantern rule does not exist\n");
        }

        hr = windows_firewall_rule_remove(policy,
                                          "Lantern Outbound Traffic");
        if (FAILED(hr)) {
            printf("Error removing Firewall rule: 0x%08lx\n", hr);
            goto error;
        }

        hr = windows_firewall_rule_exists(policy,
                                          "Lantern Outbound Traffic",
                                          &exists);
        if (FAILED(hr)) {
            printf("Error getting Firewall rule: 0x%08lx\n", hr);
            goto error;
        }
        if (exists) {
            printf("Lantern rule exists\n");
        } else {
            printf("Lantern rule does not exist\n");
        }


        /// End of Windows Vista code
        ///
        ///
/*
        // Retrieve the firewall profile currently in effect.
        hr = windows_xp_firewall_initialize(&fw_profile);
        if (FAILED(hr)) {
                printf("Firewall failed to initialize: 0x%08lx\n", hr);
                goto error;
        }

        // Check Firewall status
        BOOL is_on;
        hr = windows_firewall_is_on(fw_profile, &is_on);
        if (FAILED(hr)) {
            printf("Error retrieving Firewall status: 0x%08lx\n", hr);
            goto error;
        }
        if (is_on) {
            printf("Windows Firewall is ON -> Turning OFF\n");
            windows_firewall_turn_off(fw_profile);
        } else {
            printf("Windows Firewall is OFF -> Turning ON\n");
            windows_firewall_turn_on(fw_profile);
        }

        // Check Firewall status after switching it
        hr = windows_firewall_is_on(fw_profile, &is_on);
        if (FAILED(hr)) {
            printf("Error retrieving Firewall status: 0x%08lx\n", hr);
            goto error;
        }
        if (is_on) {
            printf("Windows Firewall is ON\n");
        } else {
            printf("Windows Firewall is OFF\n");
        }
*/
error:
        // Release the firewall profile.
        windows_firewall_cleanup(policy);

        return 0;
}
