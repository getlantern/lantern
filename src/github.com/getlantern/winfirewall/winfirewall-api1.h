/*
 * Connector API between Go and Windows Firewall COM interface
 * Windows XP API version
 */

// TEMP:
#include <stdio.h>


// Initialize the Firewall COM service
HRESULT windows_firewall_initialize_api1(OUT INetFwPolicy **policy)
{
        HRESULT hr = S_OK;
        HRESULT com_init = E_FAIL;
        INetFwMgr *fw_mgr = NULL;

        _ASSERT(policy != NULL);

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

        // Create an instance of the firewall settings manager.
        hr = CoCreateInstance(&CLSID_NetFwMgr,
                              NULL,
                              CLSCTX_INPROC_SERVER,
                              &IID_INetFwMgr,
                              (void**)&fw_mgr);
        GOTO_IF_FAILED(cleanup, hr);

        // Retrieve the local firewall policy.
        hr = INetFwMgr_get_LocalPolicy(fw_mgr, policy);
        GOTO_IF_FAILED(cleanup, hr);

cleanup:
        // Release the firewall settings manager.
        if (fw_mgr != NULL) {
                INetFwMgr_Release(fw_mgr);
        }

        return hr;
}

// Clean up the Firewall service safely
void windows_firewall_cleanup_api1(IN INetFwPolicy *policy)
{
    if (policy != NULL) {
        INetFwPolicy_Release(policy);
    }
}

// Get Firewall status: returns a boolean for ON/OFF
HRESULT windows_firewall_is_on_api1(IN INetFwPolicy *policy, OUT BOOL *fw_on)
{
    HRESULT hr = S_OK;
    VARIANT_BOOL fw_enabled;
    INetFwProfile *fw_profile;

    _ASSERT(policy != NULL);
    _ASSERT(fw_on != NULL);

    *fw_on = FALSE;

    // Retrieve the firewall profile currently in effect.
    GOTO_IF_FAILED(cleanup,
                   INetFwPolicy_get_CurrentProfile(policy, &fw_profile));

    // Get the current state of the firewall.
    GOTO_IF_FAILED(cleanup,
                   INetFwProfile_get_FirewallEnabled(fw_profile, &fw_enabled));

    // Check to see if the firewall is on.
    if (fw_enabled != VARIANT_FALSE) {
        *fw_on = TRUE;
    }

cleanup:
    if (fw_profile != NULL) {
        INetFwProfile_Release(fw_profile);
    }
    return hr;
}

//  Turn Firewall ON
HRESULT windows_firewall_turn_on_api1(IN INetFwPolicy *policy)
{
    HRESULT hr = S_OK;
    VARIANT_BOOL fw_enabled;
    INetFwProfile *fw_profile;

    _ASSERT(policy != NULL);

    // Retrieve the firewall profile currently in effect.
    GOTO_IF_FAILED(cleanup,
                   INetFwPolicy_get_CurrentProfile(policy, &fw_profile));

    // Get the current state of the firewall.
    GOTO_IF_FAILED(cleanup,
                   INetFwProfile_get_FirewallEnabled(fw_profile, &fw_enabled));

    // If it is, turn it on.
    if (fw_enabled == VARIANT_FALSE) {
        GOTO_IF_FAILED(cleanup,
                       INetFwProfile_put_FirewallEnabled(fw_profile, VARIANT_TRUE));
    }

cleanup:
    if (fw_profile != NULL) {
        INetFwProfile_Release(fw_profile);
    }
    return hr;
}

//  Turn Firewall OFF
HRESULT windows_firewall_turn_off_api1(IN INetFwPolicy *policy)
{
    HRESULT hr = S_OK;
    VARIANT_BOOL fw_enabled;
    INetFwProfile *fw_profile;

    _ASSERT(policy != NULL);

    // Retrieve the firewall profile currently in effect.
    GOTO_IF_FAILED(cleanup,
                   INetFwPolicy_get_CurrentProfile(policy, &fw_profile));

    // Get the current state of the firewall.
    GOTO_IF_FAILED(cleanup,
                   INetFwProfile_get_FirewallEnabled(fw_profile, &fw_enabled));

    // If it is, turn it off.
    if (fw_enabled == VARIANT_TRUE) {
        GOTO_IF_FAILED(cleanup,
                       INetFwProfile_put_FirewallEnabled(fw_profile, VARIANT_FALSE));
    }

cleanup:
    if (fw_profile != NULL) {
        INetFwProfile_Release(fw_profile);
    }
    return hr;
}


//  Turn Firewall OFF
HRESULT windows_firewall_rule_set_api1(IN INetFwPolicy *policy,
                                       firewall_rule_t *rule)
{
    HRESULT hr = S_OK;

    char *program_rule_name = NULL;
    char *port_rule_name = NULL;
    char *program_suffix = " (program rule)";
    char *port_suffix = " (port rule)";
    BSTR bstr_program_rule_name = NULL;
    BSTR bstr_port_rule_name = NULL;
    BSTR bstr_application = NULL;

    INetFwProfile *fw_profile;
    INetFwAuthorizedApplication* fw_app = NULL;
    INetFwAuthorizedApplications* fw_apps = NULL;
    INetFwOpenPort* fw_open_port = NULL;
    INetFwOpenPorts* fw_open_ports = NULL;

    _ASSERT(policy != NULL);

    // Retrieve the firewall profile currently in effect.
    GOTO_IF_FAILED(cleanup,
                   INetFwPolicy_get_CurrentProfile(policy, &fw_profile));

    // Emulate API2 rules by applying Application and Port
    if (rule->application != NULL) {
        // TODO: Check first if already activated
        if(TRUE) {
            program_rule_name = malloc(strlen(rule->name)+strlen(program_suffix));
            strcpy(program_rule_name, rule->name);
            strcat(program_rule_name, program_suffix);
            bstr_program_rule_name = chars_to_BSTR(program_rule_name);

            // Retrieve the authorized application collection
            GOTO_IF_FAILED(
                cleanup,
                INetFwProfile_get_AuthorizedApplications(fw_profile, &fw_apps)
                );
            // Create an instance of an authorized application
            GOTO_IF_FAILED(
                cleanup,
                CoCreateInstance(&CLSID_NetFwAuthorizedApplication,
                                 NULL,
                                 CLSCTX_INPROC_SERVER,
                                 &IID_INetFwAuthorizedApplication,
                                 (void**)&fw_app)
                );

            bstr_application = chars_to_BSTR(rule->application);

            GOTO_IF_FAILED(
                cleanup,
                INetFwAuthorizedApplication_put_ProcessImageFileName(
                    fw_app,
                    bstr_application
                    )
                );
            GOTO_IF_FAILED(
                cleanup,
                INetFwAuthorizedApplication_put_Name(fw_app, bstr_program_rule_name)
                );

            GOTO_IF_FAILED(cleanup,
                           INetFwAuthorizedApplications_Add(fw_apps, fw_app));
        }
    }

    if (rule->port != NULL) {
        // TODO: Check first if already activated
        if (FALSE) {
            port_rule_name = malloc(strlen(rule->name)+strlen(port_suffix));
            strcpy(port_rule_name, rule->name);
            strcat(port_rule_name, port_suffix);
            bstr_port_rule_name = chars_to_BSTR(port_rule_name);

            // Retrieve the collection of globally open ports
            GOTO_IF_FAILED(
                cleanup,
                INetFwProfile_get_GloballyOpenPorts(fw_profile, &fw_open_ports)
                );

            // Create an instance of an open port
            GOTO_IF_FAILED(
                cleanup,
                CoCreateInstance(&CLSID_NetFwOpenPort,
                                 NULL,
                                 CLSCTX_INPROC_SERVER,
                                 &IID_INetFwOpenPort,
                                 (void**)&fw_open_port)
                );

            // Set the port number
            GOTO_IF_FAILED(
                cleanup,
                INetFwOpenPort_put_Port(fw_open_port, atoi(rule->port))
                );

/*            // Set the IP Protocol
            hr = pFWOpenPort->put_Protocol( ipProtocol );
            if( FAILED( hr ))
                throw FW_ERR_SET_IP_PROTOCOL;
*/

            // Set the registered name
            GOTO_IF_FAILED(
                cleanup,
                INetFwOpenPort_put_Name(fw_open_port, bstr_port_rule_name)
                );

            GOTO_IF_FAILED(
                cleanup,
                INetFwOpenPorts_Add(fw_open_ports, fw_open_port)
                );
        }
    }

cleanup:
    if (fw_profile != NULL) {
        INetFwProfile_Release(fw_profile);
    }
    if (fw_app != NULL) {
        INetFwAuthorizedApplication_Release(fw_app);
    }
    if (fw_apps != NULL) {
        INetFwAuthorizedApplications_Release(fw_apps);
    }
    if (fw_open_port != NULL) {
        INetFwOpenPort_Release(fw_open_port);
    }
    if (fw_open_ports != NULL) {
        INetFwOpenPorts_Release(fw_open_ports);
    }

    SysFreeString(bstr_program_rule_name);
    SysFreeString(bstr_port_rule_name);
    SysFreeString(bstr_application);

    return hr;
}

// Get a Firewall rule
HRESULT windows_firewall_rule_get_api1(IN INetFwPolicy *policy,
                                       IN char *rule_name,
                                       firewall_rule_t **out_rule)
{
    HRESULT hr = S_OK;
    return hr;
}
// Test whether a Firewall rule exists or not
HRESULT windows_firewall_rule_exists_api1(IN INetFwPolicy *policy,
                                          IN char *rule_name,
                                          OUT BOOL *exists)
{
    HRESULT hr = S_OK;
    return hr;
}


// Remove a Firewall rule if exists.
// Windows API tests show that if there are many with the same, the
// first found will be removed, but not the rest. This is not documented.
HRESULT windows_firewall_rule_remove_api1(IN INetFwPolicy *policy,
                                          IN char *rule_name)
{
    HRESULT hr = S_OK;
    return hr;
}
