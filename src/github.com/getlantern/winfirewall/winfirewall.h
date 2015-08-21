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


// Common definitions used by both APIs
#define RETURN_IF_FAILED(expr)                  \
    do {                                        \
        hr = expr;                              \
        if (FAILED(hr)) {                       \
            return hr;                          \
        }                                       \
    } while(0)

#define GOTO_IF_FAILED(label, expr)             \
    do {                                        \
        hr = expr;                              \
        if (FAILED(hr)) {                       \
            goto label;                         \
        }                                       \
    } while(0)

#define WRAP_API(function, ...)                                 \
    if (is_win_vista_or_later)                                  \
        return function##_api2((INetFwPolicy2*) __VA_ARGS__);   \
    else                                                        \
        return function##_api1((INetFwPolicy*) __VA_ARGS__);


// Windows XP and XP SP2 versions
#include "winfirewall-api1.h"

// Windows Vista and later versions
#include "winfirewall-api2.h"

BOOL is_win_vista_or_later = FALSE;


#include <stdio.h>

inline BOOL windows_is_vista_or_later() {
    DWORD version = GetVersion();
    DWORD major_version = (DWORD)(LOBYTE(LOWORD(version)));
    DWORD minor_version = (DWORD)(HIBYTE(LOWORD(version)));

    printf("Version is %d.%d (%d)\n",
           major_version,
           minor_version);

    return (major_version > 6) || ((major_version == 6) && (minor_version >= 0));
}

HRESULT windows_firewall_initialize(OUT void **policy)
{
    if (windows_is_vista_or_later()) {
        BOOL is_win_vista_or_later = TRUE;
        return (windows_firewall_initialize_api2((INetFwPolicy2**)policy));
    }
    return (windows_firewall_initialize_api1((INetFwPolicy**)policy));
}

void windows_firewall_cleanup(IN void *policy)
{
    WRAP_API(windows_firewall_cleanup, policy)
}

HRESULT windows_firewall_is_on(IN INetFwPolicy2 *policy, OUT BOOL *is_on)
{
    WRAP_API(windows_firewall_is_on, policy, is_on)
}

HRESULT windows_firewall_turn_on(IN INetFwPolicy2 *policy)
{
    WRAP_API(windows_firewall_turn_on, policy)
}

HRESULT windows_firewall_turn_off(IN INetFwPolicy2 *policy)
{
    WRAP_API(windows_firewall_turn_off, policy)
}
/*
HRESULT windows_firewall_rule_set(IN INetFwPolicy2 *policy,
                                       IN char *rule_name,
                                       IN char *rule_description,
                                       IN char *rule_group,
                                       IN char *rule_application,
                                       IN char *rule_port,
                                       IN BOOL rule_direction_out)
{
    if (is_win_vista_or_later)
        return windows_firewall_rule_set_api2(policy,
                                              rule_name,
                                              rule_description,
                                              rule_group,
                                              rule_application,
                                              rule_port,
                                              rule_direction_out);
    else
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
*/
#undef CHOOSE_API
