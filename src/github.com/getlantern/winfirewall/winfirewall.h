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

#define WRAP_API(function, ...)                                         \
    do {                                                                \
        if (is_win_vista_or_later) {                                    \
            return function##_ascom((INetFwPolicy2*) __VA_ARGS__);      \
        }                                                               \
        else {                                                          \
            return function##_compat_xp((INetFwPolicy*) __VA_ARGS__);   \
        }                                                               \
    } while(0)


typedef struct firewall_rule_t {
    char *name;
    char *description;
    char *group;
    char *application;
    char *port;
    BOOL outbound;
} firewall_rule_t;

BSTR chars_to_BSTR(char *str);

// Windows XP and XP SP2 versions
#include "winfirewall-compat-xp.h"

// Windows Vista and later versions
#include "winfirewall-ascom.h"

#undef RETURN_IF_FAILED
#undef GOTO_IF_FAILED
#undef WRAP_API


// Get the error string from the error code
char* hr_to_string(HRESULT error)
{
    // Retrieve the system error message for the last-error code
    LPVOID msg_buf;
    FormatMessage(
        FORMAT_MESSAGE_ALLOCATE_BUFFER |
        FORMAT_MESSAGE_FROM_SYSTEM |
        FORMAT_MESSAGE_IGNORE_INSERTS,
        NULL,
        error,
        MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
        (LPTSTR)&msg_buf,
        0,
        NULL);
    return msg_buf;
}

// Convert char* to BSTR
inline BSTR chars_to_BSTR(char *str)
{
    int wslen = MultiByteToWideChar(CP_ACP, 0, str, strlen(str), 0, 0);
    BSTR bstr = SysAllocStringLen(0, wslen);
    MultiByteToWideChar(CP_ACP, 0, str, strlen(str), bstr, wslen);
    return bstr;
}

BOOL is_win_vista_or_later = FALSE;

inline BOOL windows_is_vista_or_later()
{
    DWORD version = GetVersion();
    DWORD major_version = (DWORD)(LOBYTE(LOWORD(version)));
    DWORD minor_version = (DWORD)(HIBYTE(LOWORD(version)));

    return (major_version > 6) || ((major_version == 6) && (minor_version >= 0));
}

HRESULT windows_firewall_initialize(OUT void **policy, IN BOOL as_admin)
{
    if (windows_is_vista_or_later()) {
        is_win_vista_or_later = TRUE;
        return (windows_firewall_initialize_ascom((INetFwPolicy2**)policy, as_admin));
    } else {
        is_win_vista_or_later = FALSE;
        // Windows XP doesn't require elevating privileges
        return (windows_firewall_initialize_compat_xp((INetFwPolicy**)policy));
    }
}

void windows_firewall_cleanup(IN void *policy)
{
    WRAP_API(windows_firewall_cleanup, policy);
}

HRESULT windows_firewall_is_on(IN void *policy, OUT BOOL *is_on)
{
    WRAP_API(windows_firewall_is_on, policy, is_on);
}

HRESULT windows_firewall_turn_on(IN void *policy)
{
    WRAP_API(windows_firewall_turn_on, policy);
}

HRESULT windows_firewall_turn_off(IN void *policy)
{
    WRAP_API(windows_firewall_turn_off, policy);
}

HRESULT windows_firewall_rule_set(IN void *policy, IN firewall_rule_t *rule)
{
    WRAP_API(windows_firewall_rule_set, policy, rule);
}

HRESULT windows_firewall_rule_exists(IN void *policy, IN firewall_rule_t *rule, OUT BOOL *exists)
{
    WRAP_API(windows_firewall_rule_exists, policy, rule, exists);
}

HRESULT windows_firewall_rule_remove(IN void *policy, IN firewall_rule_t *rule)
{
    WRAP_API(windows_firewall_rule_remove, policy, rule);
}

