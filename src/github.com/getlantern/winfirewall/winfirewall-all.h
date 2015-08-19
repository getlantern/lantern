/*
 * Connector API between Go and Windows Firewall COM interface
 * Windows Vista+ API version
 */

// Initialize the Firewall COM service
HRESULT windows_firewall_initialize(INetFwPolicy2** policy)
{
    HRESULT hr = S_OK;
    hr = CoCreateInstance(&CLSID_NetFwPolicy2,
                          NULL,
                          CLSCTX_INPROC_SERVER,
                          &IID_INetFwPolicy2,
                          (void**)policy);
    return hr;
}

// Clean up the Firewall service safely
void windows_firewall_cleanup(IN INetFwPolicy2 *policy)
{
    if (policy != NULL) {
        INetFwPolicy2_Release(policy);
        CoUninitialize();
    }
}

// Get Firewall status: returns a boolean for ON/OFF
HRESULT windows_firewall_is_on(IN INetFwPolicy2 *policy, OUT BOOL *fw_on)
{
    HRESULT hr = S_OK;
    VARIANT_BOOL is_enabled = FALSE;

    *fw_on = FALSE;
    hr = INetFwPolicy2_get_FirewallEnabled(policy, NET_FW_PROFILE2_PRIVATE, &is_enabled);
    if (is_enabled == VARIANT_TRUE) {
        *fw_on = TRUE;
    }

    return hr;
}
