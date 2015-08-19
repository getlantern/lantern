/*
 * Connector API between Go and Windows Firewall COM interface
 * Common header for compatibility
 */

#include <windows.h>
#include <crtdbg.h>
#include <objbase.h>
#include <oleauto.h>
#include <stdio.h>

// Firewall API
#include <initguid.h>
#include <netfw.h>


// Linker pragmas
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "oleaut32.lib")
#pragma comment(lib, "hnetcfg.lib")
