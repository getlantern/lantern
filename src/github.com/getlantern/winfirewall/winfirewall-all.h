/*
 * Connector API between Go and Windows Firewall COM interface
 * Windows Vista+ API version
 */

/*
// Forward declarations
void        Get_FirewallSettings_PerProfileType(NET_FW_PROFILE_TYPE2 ProfileTypePassed, INetFwPolicy2* pNetFwPolicy2);
HRESULT     WFCOMInitialize(INetFwPolicy2** ppNetFwPolicy2);


int __cdecl main()
{
    HRESULT hrComInit = S_OK;
    HRESULT hr = S_OK;

    INetFwPolicy2 *pNetFwPolicy2 = NULL;
    // Initialize COM.
    hrComInit = CoInitializeEx(
                    0,
                    COINIT_APARTMENTTHREADED
                    );

    // Ignore RPC_E_CHANGED_MODE; this just means that COM has already been
    // initialized with a different mode. Since we don't care what the mode is,
    // we'll just use the existing mode.
    if (hrComInit != RPC_E_CHANGED_MODE)
    {
        if (FAILED(hrComInit))
        {
            printf("CoInitializeEx failed: 0x%08lx\n", hrComInit);
            goto Cleanup;
        }
    }

    // Retrieve INetFwPolicy2
    hr = WFCOMInitialize(&pNetFwPolicy2);
    if (FAILED(hr))
    {
        goto Cleanup;
    }

    printf("Settings for the firewall domain profile:\n");
    Get_FirewallSettings_PerProfileType(NET_FW_PROFILE2_DOMAIN, pNetFwPolicy2);

    printf("Settings for the firewall private profile:\n");
    Get_FirewallSettings_PerProfileType(NET_FW_PROFILE2_PRIVATE, pNetFwPolicy2);

    printf("Settings for the firewall public profile:\n");
    Get_FirewallSettings_PerProfileType(NET_FW_PROFILE2_PUBLIC, pNetFwPolicy2);

Cleanup:

    // Release INetFwPolicy2
    if (pNetFwPolicy2 != NULL)
    {
        pNetFwPolicy2->Release();
    }

    // Uninitialize COM.
    if (SUCCEEDED(hrComInit))
    {
        CoUninitialize();
    }

    return 0;
}
*/

void Get_FirewallSettings_PerProfileType(NET_FW_PROFILE_TYPE2 profile_type, INetFwPolicy2* policy)
{
    HRESULT hr = S_OK;
    VARIANT_BOOL is_enabled = FALSE;
    NET_FW_ACTION action;

    printf("******************************************\n");

    hr = INetFwPolicy2_get_FirewallEnabled(policy, profile_type, &is_enabled);
    if(SUCCEEDED(hr)) {
        printf ("Firewall is %s\n", is_enabled ? "enabled" : "disabled");
    }
/*
    if(SUCCEEDED(pNetFwPolicy2->get_BlockAllInboundTraffic(ProfileTypePassed, &bIsEnabled)))
    {
        printf ("Block all inbound traffic is %s\n", bIsEnabled ? "enabled" : "disabled");
    }

    if(SUCCEEDED(pNetFwPolicy2->get_NotificationsDisabled(ProfileTypePassed, &bIsEnabled)))
    {
        printf ("Notifications are %s\n", bIsEnabled ? "disabled" : "enabled");
    }

    if(SUCCEEDED(pNetFwPolicy2->get_UnicastResponsesToMulticastBroadcastDisabled(ProfileTypePassed, &bIsEnabled)))
    {
        printf ("UnicastResponsesToMulticastBroadcast is %s\n", bIsEnabled ? "disabled" : "enabled");
    }

    if(SUCCEEDED(pNetFwPolicy2->get_DefaultInboundAction(ProfileTypePassed, &action)))
    {
        printf ("Default inbound action is %s\n", action != NET_FW_ACTION_BLOCK ? "Allow" : "Block");
    }

    if(SUCCEEDED(pNetFwPolicy2->get_DefaultOutboundAction(ProfileTypePassed, &action)))
    {
        printf ("Default outbound action is %s\n", action != NET_FW_ACTION_BLOCK ? "Allow" : "Block");
    }
*/
    printf("\n");
}


// Instantiate INetFwPolicy2
HRESULT windows_firewall_initialize(INetFwPolicy2** ppNetFwPolicy2)
{
    HRESULT hr = S_OK;
    hr = CoCreateInstance(&CLSID_NetFwPolicy2,
                          NULL,
                          CLSCTX_INPROC_SERVER,
                          &IID_INetFwPolicy2,
                          (void**)ppNetFwPolicy2);
    return hr;
}
