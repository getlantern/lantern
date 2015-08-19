/*
 * Connector API between Go and Windows Firewall COM interface
 */

#include <windows.h>
#include <crtdbg.h>
#include <objbase.h>
#include <oleauto.h>
#include <stdio.h>

// This hack allows for using a header from Windows 7, so previous versions
// of Windows are supported as well
#define __RPC__out_xcount_part_of(size, length)
#define __RPC__in_xcount_of(size)
#define __RPC__in_xcount_full_of(size)
#define __RPC__in_range_of(min, max)
#define __RPC__in_range(min, max)
#define __RPC__inout_xcount_of(size)

#include <netfw.h>


#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "oleaut32.lib")
#pragma comment(lib, "hnetcfg.lib")

#ifdef __MINGW32__
#include <initguid.h>
DEFINE_GUID(IID_INetFwAuthorizedApplication,      0xb5e64ffa, 0xc2c5, 0x444e, 0xa3, 0x01, 0xfb, 0x5e, 0x00, 0x01, 0x80, 0x50);
DEFINE_GUID(IID_INetFwMgr,                        0xf7898af5, 0xcac4, 0x4632, 0xa2, 0xec, 0xda, 0x06, 0xe5, 0x11, 0x1a, 0xf2);
DEFINE_GUID(IID_INetFwOpenPort,                   0xe0483ba0, 0x47ff, 0x4d9c, 0xa6, 0xd6, 0x77, 0x41, 0xd0, 0xb1, 0x95, 0xf7);

DEFINE_GUID(CLSID_NetFwAuthorizedApplication,     0xec9846b3, 0x2762, 0x4a6b, 0xa2, 0x14, 0x6a, 0xcb, 0x60, 0x34, 0x62, 0xd2);
DEFINE_GUID(CLSID_NetFwMgr,                       0x304ce942, 0x6e39, 0x40d8, 0x94, 0x3a, 0xb9, 0x13, 0xc4, 0x0c, 0x9c, 0xd4);
DEFINE_GUID(CLSID_NetFwOpenPort,                  0x0ca545c6, 0x37ad, 0x4a6c, 0xbf, 0x92, 0x9f, 0x76, 0x10, 0x06, 0x7e, 0xf5);
#endif

// Initialize the Firewall COM service
HRESULT windows_firewall_initialize(OUT INetFwProfile **fw_profile)
{
        HRESULT hr = S_OK;
        INetFwMgr *fw_mgr = NULL;
        INetFwPolicy *fw_policy = NULL;

        _ASSERT(fw_profile != NULL);

        *fw_profile = NULL;

        // Create an instance of the firewall settings manager.
        hr = CoCreateInstance(&CLSID_NetFwMgr,
                              NULL,
                              CLSCTX_INPROC_SERVER,
                              &IID_INetFwMgr,
                              (void**)&fw_mgr);
        if (FAILED(hr)) {
                printf("CoCreateInstance failed: 0x%08lx\n", hr);
                goto error;
        }

        // Retrieve the local firewall policy.
        hr = INetFwMgr_get_LocalPolicy(fw_mgr, &fw_policy);
        if (FAILED(hr)) {
                printf("get_LocalPolicy failed: 0x%08lx\n", hr);
                goto error;
        }

        // Retrieve the firewall profile currently in effect.
        hr = INetFwPolicy_get_CurrentProfile(fw_policy, fw_profile);
        if (FAILED(hr)) {
                printf("get_CurrentProfile failed: 0x%08lx\n", hr);
                goto error;
        }

error:
        // Release the local firewall policy.
        if (fw_policy != NULL) {
                INetFwPolicy_Release(fw_policy);
        }

        // Release the firewall settings manager.
        if (fw_mgr != NULL) {
                INetFwMgr_Release(fw_mgr);
        }

        return hr;
}

// Clean up the Firewall service safely
void windows_firewall_cleanup(IN INetFwProfile *fw_profile)
{
    if (fw_profile != NULL) {
        INetFwProfile_Release(fw_profile);
    }
}

// Get Firewall status: returns a boolean for ON/OFF
HRESULT windows_firewall_is_on(IN INetFwProfile *fw_profile, OUT BOOL *fw_on)
{
    HRESULT hr = S_OK;
    VARIANT_BOOL fw_enabled;

    _ASSERT(fw_profile != NULL);
    _ASSERT(fw_on != NULL);

    *fw_on = FALSE;

    // Get the current state of the firewall.
    hr = INetFwProfile_get_FirewallEnabled(fw_profile, &fw_enabled);
    if (FAILED(hr)) {
        printf("get_FirewallEnabled failed: 0x%08lx\n", hr);
        goto error;
    }

    // Check to see if the firewall is on.
    if (fw_enabled != VARIANT_FALSE) {
        *fw_on = TRUE;
    }

error:
    return hr;
}

//  Turn Firewall ON
HRESULT windows_firewall_turn_on(IN INetFwProfile *fw_profile)
{
    HRESULT hr = S_OK;
    BOOL fw_on;

    _ASSERT(fw_profile != NULL);

    // Check the current firewall status first
    hr = windows_firewall_is_on(fw_profile, &fw_on);
    if (FAILED(hr)) {
        printf("WindowsFirewallIsOn failed: 0x%08lx\n", hr);
        goto error;
    }

    // If it is, turn it on.
    if (!fw_on) {
        // Turn the firewall on.
        hr = INetFwProfile_put_FirewallEnabled(fw_profile, VARIANT_TRUE);
        if (FAILED(hr)) {
            printf("put_FirewallEnabled failed: 0x%08lx\n", hr);
            goto error;
        }
        printf("The firewall is now on.\n");
    }

error:
    return hr;
}

//  Turn Firewall OFF
HRESULT windows_firewall_turn_off(IN INetFwProfile *fw_profile)
{
    HRESULT hr = S_OK;
    BOOL fw_on;

    _ASSERT(fw_profile != NULL);

    // Check the current firewall status first
    hr = windows_firewall_is_on(fw_profile, &fw_on);
    if (FAILED(hr)) {
        printf("WindowsFirewallIsOn failed: 0x%08lx\n", hr);
        goto error;
    }

    // If it is, turn it on.
    if (fw_on) {
        // Turn the firewall on.
        hr = INetFwProfile_put_FirewallEnabled(fw_profile, VARIANT_FALSE);
        if (FAILED(hr)) {
            printf("put_FirewallEnabled failed: 0x%08lx\n", hr);
            goto error;
        }
        printf("The firewall is now off.\n");
    }

error:
    return hr;
}
