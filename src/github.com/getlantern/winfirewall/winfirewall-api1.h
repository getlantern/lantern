/*
 * Connector API between Go and Windows Firewall COM interface
 * Windows XP API version
 */

// TEMP:
#include <stdio.h>


// Initialize the Firewall COM service
HRESULT windows_firewall_initialize_api1(OUT INetFwProfile **fw_profile)
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
void windows_xp_firewall_cleanup(IN INetFwProfile *fw_profile)
{
    if (fw_profile != NULL) {
        INetFwProfile_Release(fw_profile);
    }
}

// Get Firewall status: returns a boolean for ON/OFF
HRESULT windows_xp_firewall_is_on(IN INetFwProfile *fw_profile, OUT BOOL *fw_on)
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
HRESULT windows_xp_firewall_turn_on(IN INetFwProfile *fw_profile)
{
    HRESULT hr = S_OK;
    BOOL fw_on;

    _ASSERT(fw_profile != NULL);

    // Check the current firewall status first
    hr = windows_xp_firewall_is_on(fw_profile, &fw_on);
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
HRESULT windows_xp_firewall_turn_off(IN INetFwProfile *fw_profile)
{
    HRESULT hr = S_OK;
    BOOL fw_on;

    _ASSERT(fw_profile != NULL);

    // Check the current firewall status first
    hr = windows_xp_firewall_is_on(fw_profile, &fw_on);
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
