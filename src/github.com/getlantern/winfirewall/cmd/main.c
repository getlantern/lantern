/*
 * Test utility for Windows Firewall COM interface library
 */

#include "winfirewall.h"

#include <stdio.h>
#include <strsafe.h>

void error_exit(DWORD error, LPTSTR lpszFunction)
{
    // Retrieve the system error message for the last-error code

    LPVOID lpMsgBuf;
    LPVOID lpDisplayBuf;

    FormatMessage(
        FORMAT_MESSAGE_ALLOCATE_BUFFER |
        FORMAT_MESSAGE_FROM_SYSTEM |
        FORMAT_MESSAGE_IGNORE_INSERTS,
        NULL,
        error,
        MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
        (LPTSTR) &lpMsgBuf,
        0, NULL );

    // Display the error message and exit the process
    lpDisplayBuf = (LPVOID)LocalAlloc(LMEM_ZEROINIT,
        (lstrlen((LPCTSTR)lpMsgBuf) + lstrlen((LPCTSTR)lpszFunction) + 40) * sizeof(TCHAR));
    StringCchPrintf((LPTSTR)lpDisplayBuf,
        LocalSize(lpDisplayBuf) / sizeof(TCHAR),
        TEXT("%s failed with error %d: %s"),
        lpszFunction, error, lpMsgBuf);
    MessageBox(NULL, (LPCTSTR)lpDisplayBuf, TEXT("Error"), MB_OK);

    LocalFree(lpMsgBuf);
    LocalFree(lpDisplayBuf);
    ExitProcess(error);
}


int main(int argc, wchar_t* argv[])
{
        HRESULT hr = S_OK;
        void *policy = NULL;
        void *elevated_policy = NULL;
        LPVOID error_msg;

        hr = windows_firewall_initialize(&policy, FALSE);
        if (FAILED(hr)) {
            printf("Policy creation failed: 0x%08lx\n", hr);
            goto error;
        }
        printf("Windows Firewall initialized\n");

        BOOL is_on;
        hr = windows_firewall_is_on(policy, &is_on);
        if (FAILED(hr)) {
            printf("Error retrieving Firewall status: 0x%08lx\n", hr);
            goto error;
        }

        GOTO_IF_FAILED(
            error,
            windows_firewall_initialize(&elevated_policy, TRUE)
            );

        if (is_on) {
            printf("Windows Firewall is ON -> Turning OFF\n");
            hr = windows_firewall_turn_off(elevated_policy);
        } else {
            printf("Windows Firewall is OFF -> Turning ON\n");
            hr = windows_firewall_turn_on(elevated_policy);
        }
        if (FAILED(hr)) {
            printf("Failed to switch Firewall: 0x%08lx\n", hr);
            goto error;
        }

        firewall_rule_t new_rule = {
            .name = "Lantern Outbound Traffic",
            .description = "Allow outbound traffic from Lantern",
            .group = "Internet Access",
            .application = "C:\\WINDOWS\\explorer.exe",
            .outbound = TRUE,
        };

        hr = windows_firewall_rule_set(elevated_policy, &new_rule);
        if (FAILED(hr)) {
            printf("Error setting Firewall rule: 0x%08lx\n", hr);
            goto error;
        }

        // Here we are using a fake rule to test existence against it, but ideally
        // we will use the same struct created above, so no field is left behind.
        // That's how we can handle both APIs sanely, since API2 has the concept of
        // rules but for API1 (pre Windows Vista) we need to carry the program and
        // port components in this struct and create separate rules.
        BOOL exists;
        firewall_rule_t rule_stub = {
            .name = "Lantern Outbound Traffic",
            .application = "C:\\WINDOWS\\explorer.exe",
        };
        hr = windows_firewall_rule_exists(policy, &rule_stub, &exists);
        if (FAILED(hr)) {
            printf("Error getting Firewall rule: 0x%08lx\n", hr);
            goto error;
        }
        if (exists) {
            printf("Lantern rule exists\n");
        } else {
            printf("Lantern rule does not exist\n");
        }

        hr = windows_firewall_rule_remove(elevated_policy, &rule_stub);
        if (FAILED(hr)) {
            printf("Error removing Firewall rule: 0x%08lx\n", hr);
            goto error;
        }

        hr = windows_firewall_rule_exists(policy, &rule_stub, &exists);
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
        error_msg = hr_to_string(hr);
        printf("Error: %s\n", error_msg);
        LocalFree(error_msg);

        error_exit(hr, "");

        // Release the firewall profile.
        windows_firewall_cleanup(policy);
        windows_firewall_cleanup(elevated_policy);

        return 0;
}
