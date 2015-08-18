/*
 * Test utility for Windows Firewall COM interface library
 */

#include "winfirewall.h"

int main(int argc, wchar_t* argv[])
{
        HRESULT hr = S_OK;
        HRESULT comInit = E_FAIL;
        INetFwProfile* fwProfile = NULL;

        // Initialize COM.
        comInit = CoInitializeEx(0, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);

        // Ignore RPC_E_CHANGED_MODE; this just means that COM has already been
        // initialized with a different mode. Since we don't care what the mode is,
        // we'll just use the existing mode.
        if (comInit != RPC_E_CHANGED_MODE)
        {
                hr = comInit;
                if (FAILED(hr))
                {
                        printf("CoInitializeEx failed: 0x%08lx\n", hr);
                        goto error;
                }
        }

        // Retrieve the firewall profile currently in effect.
        hr = windows_firewall_initialize(&fwProfile);
        if (FAILED(hr))
        {
                printf("WindowsFirewallInitialize failed: 0x%08lx\n", hr);
                goto error;
        }

error:
        // Release the firewall profile.
        // TODO

        // Uninitialize COM.
        if (SUCCEEDED(comInit))
        {
                CoUninitialize();
        }

        return 0;
}
