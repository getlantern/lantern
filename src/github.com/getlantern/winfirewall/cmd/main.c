/*
 * Test utility for Windows Firewall COM interface library
 */

#include "winfirewall.h"

#include <stdio.h>

int main(int argc, wchar_t* argv[])
{
        HRESULT hr = S_OK;
        void *policy = NULL;

        hr = windows_firewall_initialize(&policy);
        if (FAILED(hr)) {
            printf("Policy creation failed: 0x%08lx\n", hr);
        }
        printf("Windows Firewall initialized\n");

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
                printf("Failed to switch Firewall: 0x%08lx\n", hr);
                goto error;
        }

        firewall_rule_t new_rule = {
            "Lantern Outbound Traffic",
            "Allow outbound traffic from Lantern",
            "Internet Access",
            "Lantern.exe",
            "",
            TRUE,
            NULL,
        };
        hr = windows_firewall_rule_set(policy, &new_rule);
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

error:
        // Release the firewall profile.
        windows_firewall_cleanup(policy);

        return 0;
}
