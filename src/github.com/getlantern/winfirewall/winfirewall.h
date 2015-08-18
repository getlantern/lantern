/*
 * Connector API between Go and Windows Firewall COM interface
 */

#include <windows.h>
#include <crtdbg.h>
#include <netfw.h>
#include <objbase.h>
#include <oleauto.h>
#include <stdio.h>

#ifdef __MINGW32__
#include <initguid.h>
DEFINE_GUID(IID_INetFwAuthorizedApplication,      0xb5e64ffa, 0xc2c5, 0x444e, 0xa3, 0x01, 0xfb, 0x5e, 0x00, 0x01, 0x80, 0x50);
DEFINE_GUID(IID_INetFwMgr,                        0xf7898af5, 0xcac4, 0x4632, 0xa2, 0xec, 0xda, 0x06, 0xe5, 0x11, 0x1a, 0xf2);
DEFINE_GUID(IID_INetFwOpenPort,                   0xe0483ba0, 0x47ff, 0x4d9c, 0xa6, 0xd6, 0x77, 0x41, 0xd0, 0xb1, 0x95, 0xf7);

DEFINE_GUID(CLSID_NetFwAuthorizedApplication,     0xec9846b3, 0x2762, 0x4a6b, 0xa2, 0x14, 0x6a, 0xcb, 0x60, 0x34, 0x62, 0xd2);
DEFINE_GUID(CLSID_NetFwMgr,                       0x304ce942, 0x6e39, 0x40d8, 0x94, 0x3a, 0xb9, 0x13, 0xc4, 0x0c, 0x9c, 0xd4);
DEFINE_GUID(CLSID_NetFwOpenPort,                  0x0ca545c6, 0x37ad, 0x4a6c, 0xbf, 0x92, 0x9f, 0x76, 0x10, 0x06, 0x7e, 0xf5);
#endif

HRESULT windows_firewall_initialize(OUT INetFwProfile** fwProfile)
{
        HRESULT hr = S_OK;
        INetFwMgr* fwMgr = NULL;
        INetFwPolicy* fwPolicy = NULL;

        _ASSERT(fwProfile != NULL);

        *fwProfile = NULL;

        // Create an instance of the firewall settings manager.
        hr = CoCreateInstance(&CLSID_NetFwMgr,
                              NULL,
                              CLSCTX_INPROC_SERVER,
                              &IID_INetFwMgr,
                              (void**)&fwMgr);
        if (FAILED(hr))
        {
                printf("CoCreateInstance failed: 0x%08lx\n", hr);
                goto error;
        }

        LPOLESTR str;
        hr = StringFromCLSID(&CLSID_NetFwMgr, &str );
        if (FAILED(hr))
        {
                printf("StringFromCLSID failed: 0x%08lx\n", hr);
                goto error;
        }
        else
        {
                CHAR  szCLSID[60];
                WideCharToMultiByte(CP_ACP, 0, str, -1, szCLSID, 60, NULL, NULL);
                printf("StringFromCLSID result: %s\n", szCLSID);
        }

        // Retrieve the local firewall policy.
        hr = INetFwMgr_get_LocalPolicy(fwMgr, &fwPolicy);
        if (FAILED(hr))
        {
                printf("get_LocalPolicy failed: 0x%08lx\n", hr);
                goto error;
        }

        // Retrieve the firewall profile currently in effect.
        hr = INetFwPolicy_get_CurrentProfile(fwPolicy, fwProfile);
        if (FAILED(hr))
        {
                printf("get_CurrentProfile failed: 0x%08lx\n", hr);
                goto error;
        }

error:
        // Release the local firewall policy.
        if (fwPolicy != NULL)
        {
                INetFwPolicy_Release(fwPolicy);
        }

        // Release the firewall settings manager.
        if (fwMgr != NULL)
        {
                INetFwMgr_Release(fwMgr);
        }
        return hr;
}
