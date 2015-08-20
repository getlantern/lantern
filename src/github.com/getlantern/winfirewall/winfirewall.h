/*
 * Connector API between Go and Windows Firewall COM interface
 */

#include <windows.h>
#include <crtdbg.h>
#include <objbase.h>
#include <oleauto.h>

// Firewall API
#include <initguid.h>
#include <netfw.h>


// Linker pragmas
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "oleaut32.lib")
#pragma comment(lib, "hnetcfg.lib")


// Windows XP and XP SP2 versions
#include "winfirewall-api1.h"

// Windows Vista and later versions
#include "winfirewall-api2.h"

BOOL is_win_vista_or_later = FALSE;


HRESULT windows_firewall_initialize(INetFwPolicy2** policy)
{
    if (windows_is_vista_or_later()) {
        BOOL is_win_vista_or_later = TRUE;
        return windows_firewall_initialize_api2(policy);
    }
    return windows_firewall_initialize_api1(policy);
}

void windows_firewall_cleanup(IN INetFwPolicy2 *policy)
{
    return windows_firewall_cleanup_api2(policy);
}

HRESULT windows_firewall_is_on(IN INetFwPolicy2 *policy, OUT BOOL *fw_on)
{
    return windows_firewall_is_on_api2(policy, fw_on);
}

HRESULT windows_firewall_turn_on(IN INetFwPolicy2 *policy)
{
    return windows_firewall_turn_on_api2(policy);
}

HRESULT windows_firewall_turn_off(IN INetFwPolicy2 *policy)
{
    return windows_firewall_turn_off_api2(policy);
}

HRESULT windows_firewall_rule_set(IN INetFwPolicy2 *policy,
                                       IN char *rule_name,
                                       IN char *rule_description,
                                       IN char *rule_group,
                                       IN char *rule_application,
                                       IN char *rule_port,
                                       IN BOOL rule_direction_out)
{
    return windows_firewall_rule_set_api2(policy,
                                          rule_name,
                                          rule_description,
                                          rule_group,
                                          rule_application,
                                          rule_port,
                                          rule_direction_out);
}

HRESULT windows_firewall_rule_get(IN INetFwPolicy2 *policy,
                                       IN char *rule_name,
                                       OUT INetFwRule **out_rule)
{
    return windows_firewall_rule_get_api2(policy, rule_name, out_rule);
}

HRESULT windows_firewall_rule_exists(IN INetFwPolicy2 *policy,
                                          IN char *rule_name,
                                          OUT BOOL *exists)
{
    return windows_firewall_rule_exists_api2(policy, rule_name, exists);
}

HRESULT windows_firewall_rule_remove(IN INetFwPolicy2 *policy,
                                     IN char *rule_name)
{
    return windows_firewall_rule_remove_api2(policy, rule_name);
}
