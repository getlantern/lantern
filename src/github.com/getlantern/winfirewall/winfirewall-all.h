/*
 * Connector API between Go and Windows Firewall COM interface
 * Windows Vista+ API version
 */

#define RETURN_IF_FAILED(expr)                  \
    do {                                        \
        HRESULT hr = expr;                      \
        if (FAILED(hr)) {                       \
            return hr;                          \
        }                                       \
    } while(0)

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
// It will return ON if any of the profiles has the firewall enabled.
HRESULT windows_firewall_is_on(IN INetFwPolicy2 *policy, OUT BOOL *fw_on)
{
    HRESULT hr = S_OK;
    VARIANT_BOOL is_enabled = FALSE;

    *fw_on = FALSE;
    hr = INetFwPolicy2_get_FirewallEnabled(policy, NET_FW_PROFILE2_DOMAIN, &is_enabled);
    if (is_enabled == VARIANT_TRUE) {
        *fw_on = TRUE;
        return hr;
    }

    hr = INetFwPolicy2_get_FirewallEnabled(policy, NET_FW_PROFILE2_PRIVATE, &is_enabled);
    if (is_enabled == VARIANT_TRUE) {
        *fw_on = TRUE;
        return hr;
    }

    hr = INetFwPolicy2_get_FirewallEnabled(policy, NET_FW_PROFILE2_PUBLIC, &is_enabled);
    if (is_enabled == VARIANT_TRUE) {
        *fw_on = TRUE;
    }

    return hr;
}

//  Turn Firewall ON
HRESULT windows_firewall_turn_on(IN INetFwPolicy2 *policy)
{
    HRESULT hr = S_OK;
    BOOL fw_on;

    _ASSERT(fw_profile != NULL);

    // Check the current firewall status first
    RETURN_IF_FAILED(windows_firewall_is_on(policy, &fw_on));

    // If it is off, turn it on.
    if (!fw_on) {
        RETURN_IF_FAILED(
            INetFwPolicy2_put_FirewallEnabled(policy, NET_FW_PROFILE2_DOMAIN, TRUE));
        RETURN_IF_FAILED(
            INetFwPolicy2_put_FirewallEnabled(policy, NET_FW_PROFILE2_PRIVATE, TRUE));
        RETURN_IF_FAILED(
            INetFwPolicy2_put_FirewallEnabled(policy, NET_FW_PROFILE2_PUBLIC, TRUE));
    }
}

//  Turn Firewall OFF
HRESULT windows_firewall_turn_off(IN INetFwPolicy2 *policy)
{
    HRESULT hr = S_OK;
    BOOL fw_on;

    _ASSERT(fw_profile != NULL);

    // Check the current firewall status first
    hr = windows_firewall_is_on(policy, &fw_on);
    RETURN_IF_FAILED(hr);

    // If it is on, turn it off.
    if (fw_on) {
        RETURN_IF_FAILED(
            INetFwPolicy2_put_FirewallEnabled(policy, NET_FW_PROFILE2_DOMAIN, FALSE));
        RETURN_IF_FAILED(
            INetFwPolicy2_put_FirewallEnabled(policy, NET_FW_PROFILE2_PRIVATE, FALSE));
        RETURN_IF_FAILED(
            INetFwPolicy2_put_FirewallEnabled(policy, NET_FW_PROFILE2_PUBLIC, FALSE));
    }
    return hr;
}
