/*
 * Connector API between Go and Windows Firewall COM interface
 * Windows Vista+ API version (Advanced Security COM API)
 */


#include <strsafe.h>

// Create a COM instance with elevated privileges
HRESULT CoCreateInstanceAsAdmin(REFCLSID rclsid, REFIID riid, OUT void ** ppv)
{
    HRESULT hr = S_OK;
    BIND_OPTS3 bo;
    WCHAR wsz_clsid[50];
    TCHAR str_clsid[50];
    TCHAR moniker_name[300];
    BSTR bstr_moniker_name = NULL;

    StringFromGUID2(rclsid, wsz_clsid, sizeof(wsz_clsid)/sizeof(wsz_clsid[0]));
    wcstombs(str_clsid, wsz_clsid, 50);

    GOTO_IF_FAILED(
        cleanup,
        StringCchPrintf(moniker_name,
                        sizeof(moniker_name)/sizeof(moniker_name[0]),
                        "Elevation:Administrator!new:%s",
                        str_clsid)
        );

    memset(&bo, 0, sizeof(bo));
    bo.cbStruct = sizeof(bo);
    bo.dwClassContext = CLSCTX_LOCAL_SERVER;

    bstr_moniker_name = chars_to_BSTR(moniker_name);

    hr = CoGetObject(bstr_moniker_name, (BIND_OPTS*)&bo, riid, ppv);

cleanup:
    SysFreeString(bstr_moniker_name);

    return hr;
}

// Initialize the Firewall COM service
HRESULT windows_firewall_initialize_as_api(OUT INetFwPolicy2** policy, IN BOOL as_admin)
{
    HRESULT hr = S_OK;
    HRESULT com_init = E_FAIL;

    // Initialize COM.
    com_init = CoInitializeEx(0, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);

    // Ignore RPC_E_CHANGED_MODE; this just means that COM has already been
    // initialized with a different mode. Since we don't care what the mode is,
    // we'll just use the existing mode.
    if (com_init != RPC_E_CHANGED_MODE) {
        if (FAILED(com_init)) {
            return com_init;
        }
    }

    // Create Policy2 instance
    if (as_admin) {
        hr = CoCreateInstanceAsAdmin(&CLSID_NetFwPolicy2,
                                     &IID_INetFwPolicy2,
                                     (void**)policy);
    } else {
        hr = CoCreateInstance(&CLSID_NetFwPolicy2,
                          NULL,
                          CLSCTX_INPROC_SERVER,
                          &IID_INetFwPolicy2,
                          (void**)policy);
    }
    return hr;
}

// Clean up the Firewall service safely
void windows_firewall_cleanup_as_api(IN INetFwPolicy2 *policy)
{
    if (policy != NULL) {
        INetFwPolicy2_Release(policy);
        CoUninitialize();
    }
}

// Get Firewall status: returns a boolean for ON/OFF
// It will return ON if any of the profiles has the firewall enabled.
HRESULT windows_firewall_is_on_as_api(IN INetFwPolicy2 *policy, OUT BOOL *fw_on)
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
HRESULT windows_firewall_turn_on_as_api(IN INetFwPolicy2 *policy)
{
    HRESULT hr = S_OK;
    BOOL fw_on;

    _ASSERT(fw_profile != NULL);

    // Check the current firewall status first
    RETURN_IF_FAILED(windows_firewall_is_on_as_api(policy, &fw_on));

    // If it is off, turn it on.
    if (!fw_on) {
        RETURN_IF_FAILED(
            INetFwPolicy2_put_FirewallEnabled(policy, NET_FW_PROFILE2_DOMAIN, TRUE));
        RETURN_IF_FAILED(
            INetFwPolicy2_put_FirewallEnabled(policy, NET_FW_PROFILE2_PRIVATE, TRUE));
        RETURN_IF_FAILED(
            INetFwPolicy2_put_FirewallEnabled(policy, NET_FW_PROFILE2_PUBLIC, TRUE));
    }
    return hr;
}

//  Turn Firewall OFF
HRESULT windows_firewall_turn_off_as_api(IN INetFwPolicy2 *policy)
{
    HRESULT hr = S_OK;
    BOOL fw_on;

    _ASSERT(fw_profile != NULL);

    // Check the current firewall status first
    hr = windows_firewall_is_on_as_api(policy, &fw_on);
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

// Set a Firewall rule
HRESULT windows_firewall_rule_set_as_api(IN INetFwPolicy2 *policy,
                                       firewall_rule_t *rule)
{
    HRESULT hr = S_OK;
    INetFwRules *fw_rules = NULL;
    INetFwRule *fw_rule = NULL;
    long current_profiles = 0;

    BSTR bstr_rule_name = chars_to_BSTR(rule->name);
    BSTR bstr_rule_description = chars_to_BSTR(rule->description);
    BSTR bstr_rule_group = chars_to_BSTR(rule->group);
    BSTR bstr_rule_application = chars_to_BSTR(rule->application);
    BSTR bstr_rule_ports = chars_to_BSTR(rule->port);

    // Retrieve INetFwRules
    GOTO_IF_FAILED(cleanup,
                   INetFwPolicy2_get_Rules(policy, &fw_rules));

    // Add rule to all profiles
    current_profiles = NET_FW_PROFILE2_ALL;

    // Create a new Firewall Rule object.
    hr = CoCreateInstance(&CLSID_NetFwRule,
                          NULL,
                          CLSCTX_INPROC_SERVER,
                          &IID_INetFwRule,
                          (void**)&fw_rule);
    GOTO_IF_FAILED(cleanup, hr);

    // Populate the Firewall Rule object
    INetFwRule_put_Name(fw_rule, bstr_rule_name);
    INetFwRule_put_Description(fw_rule, bstr_rule_description);
    INetFwRule_put_ApplicationName(fw_rule, bstr_rule_application);
    INetFwRule_put_Protocol(fw_rule, NET_FW_IP_PROTOCOL_ANY);
    INetFwRule_put_LocalPorts(fw_rule, bstr_rule_ports);
    INetFwRule_put_Direction(fw_rule, rule->direction_out ?
                             NET_FW_RULE_DIR_OUT : NET_FW_RULE_DIR_IN);
    INetFwRule_put_Grouping(fw_rule, bstr_rule_group);
    INetFwRule_put_Profiles(fw_rule, current_profiles);
    INetFwRule_put_Action(fw_rule, NET_FW_ACTION_ALLOW);
    INetFwRule_put_Enabled(fw_rule, VARIANT_TRUE);

    // Add the Firewall Rule
    GOTO_IF_FAILED(cleanup,
                   INetFwRules_Add(fw_rules, fw_rule));

cleanup:
    SysFreeString(bstr_rule_name);
    SysFreeString(bstr_rule_description);
    SysFreeString(bstr_rule_group);
    SysFreeString(bstr_rule_application);
    SysFreeString(bstr_rule_ports);

    // Release the INetFwRule object
    if (fw_rules != NULL) {
        INetFwRule_Release(fw_rule);
    }

    // Release the INetFwRules object
    if (fw_rules != NULL) {
        INetFwRules_Release(fw_rules);
    }
}

// Test whether a Firewall rule exists or not
HRESULT windows_firewall_rule_exists_as_api(IN INetFwPolicy2 *policy,
                                          IN firewall_rule_t *rule,
                                          OUT BOOL *exists)
{
        HRESULT hr = S_OK;
    INetFwRules *fw_rules = NULL;
    INetFwRule *fw_rule = NULL;
    BSTR bstr_rule_name = chars_to_BSTR(rule->name);

    // Retrieve INetFwRules
    GOTO_IF_FAILED(cleanup, INetFwPolicy2_get_Rules(policy, &fw_rules));

    // Create a new Firewall Rule object.
    hr = CoCreateInstance(&CLSID_NetFwRule,
                          NULL,
                          CLSCTX_INPROC_SERVER,
                          &IID_INetFwRule,
                          (void**)&fw_rule);
    GOTO_IF_FAILED(cleanup, hr);

    INetFwRules_Item(fw_rules, bstr_rule_name, &fw_rule);
    GOTO_IF_FAILED(cleanup, hr);

    if (fw_rule != NULL) {
        *exists = TRUE;
    } else {
        *exists = FALSE;
    }

cleanup:
    SysFreeString(bstr_rule_name);

    return hr;
}


// Remove a Firewall rule if exists.
// Windows API tests show that if there are many with the same, the
// first found will be removed, but not the rest. This is not documented.
HRESULT windows_firewall_rule_remove_as_api(IN INetFwPolicy2 *policy,
                                          IN firewall_rule_t *rule)
{
    HRESULT hr = S_OK;
    INetFwRules *fw_rules = NULL;
    INetFwRule *fw_rule = NULL;
    BSTR bstr_rule_name = chars_to_BSTR(rule->name);

    // Retrieve INetFwRules
    GOTO_IF_FAILED(cleanup, INetFwPolicy2_get_Rules(policy, &fw_rules));

    INetFwRules_Remove(fw_rules, bstr_rule_name);
    GOTO_IF_FAILED(cleanup, hr);

cleanup:
    SysFreeString(bstr_rule_name);

    return hr;
}
