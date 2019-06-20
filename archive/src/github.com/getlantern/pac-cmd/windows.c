#include <stdlib.h>
#include <windows.h>
#include <Wininet.h>
#include <ras.h>
#include <tchar.h>
#include <stdio.h>
#include "common.h"

void reportWindowsError(const char* action) {
  LPTSTR pErrMsg = NULL;
  DWORD errCode = GetLastError();
  FormatMessage(FORMAT_MESSAGE_ALLOCATE_BUFFER|
      FORMAT_MESSAGE_FROM_SYSTEM|
      FORMAT_MESSAGE_ARGUMENT_ARRAY,
      NULL,
      errCode,
      LANG_NEUTRAL,
      pErrMsg,
      0,
      NULL);
  fprintf(stderr, "Error %s: %lu %s\n", action, errCode, pErrMsg);
}

// Stolen from https://github.com/getlantern/winproxy
// Figure out which Dial-Up or VPN connection is active; in a normal LAN connection, this should
// return NULL. NOTE: For some reason this method fails when compiled in Debug mode but works
// every time in Release mode.
LPTSTR FindActiveConnection() {
  DWORD dwCb = sizeof(RASCONN);
  DWORD dwErr = ERROR_SUCCESS;
  DWORD dwRetries = 5;
  DWORD dwConnections = 0;
  RASCONN* lpRasConn = NULL;
  RASCONNSTATUS rasconnstatus;
  rasconnstatus.dwSize = sizeof(RASCONNSTATUS);

  //
  // Loop through in case the information from RAS changes between calls.
  //
  while (dwRetries--) {
    // If the memory is allocated, free it.
    if (NULL != lpRasConn) {
      HeapFree(GetProcessHeap(), 0, lpRasConn);
      lpRasConn = NULL;
    }

    // Allocate the size needed for the RAS structure.
    lpRasConn = (RASCONN*)HeapAlloc(GetProcessHeap(), 0, dwCb);
    if (NULL == lpRasConn) {
      dwErr = ERROR_NOT_ENOUGH_MEMORY;
      break;
    }

    // Set the structure size for version checking purposes.
    lpRasConn->dwSize = sizeof(RASCONN);

    // Call the RAS API then exit the loop if we are successful or an unknown
    // error occurs.
    dwErr = RasEnumConnections(lpRasConn, &dwCb, &dwConnections);
    if (ERROR_INSUFFICIENT_BUFFER != dwErr) {
      break;
    }
  }
  //
  // In the success case, print the names of the connections.
  //
  if (ERROR_SUCCESS == dwErr) {
    DWORD i;
    for (i = 0; i < dwConnections; i++) {
      RasGetConnectStatus(lpRasConn[i].hrasconn, &rasconnstatus);
      if (rasconnstatus.rasconnstate == RASCS_Connected){
        return lpRasConn[i].szEntryName;
      }

    }
  }
  return NULL; // Couldn't find an active dial-up/VPN connection; return NULL
}

int togglePac(bool turnOn, const char* pacUrl)
{
  int ret = RET_NO_ERROR;

  INTERNET_PER_CONN_OPTION_LIST options;
  DWORD   dwBufferSize = sizeof(options);
  options.dwSize = dwBufferSize;
  options.pszConnection = FindActiveConnection();

  options.dwOptionCount = 2;
  options.dwOptionError = 0;
  options.pOptions = (INTERNET_PER_CONN_OPTION*)calloc(2, sizeof(INTERNET_PER_CONN_OPTION));
  if(!options.pOptions) {
    return NO_MEMORY;
  }

  options.pOptions[0].dwOption = INTERNET_PER_CONN_FLAGS;
  options.pOptions[1].dwOption = INTERNET_PER_CONN_AUTOCONFIG_URL;
  if (turnOn) {
    options.pOptions[0].Value.dwValue = PROXY_TYPE_AUTO_PROXY_URL;
    options.pOptions[1].Value.pszValue = (char*)pacUrl;
  }
  else {
    if (strlen(pacUrl) == 0) {
      goto turnOff;
    } 
    if(!InternetQueryOption(NULL, INTERNET_OPTION_PER_CONNECTION_OPTION, &options, &dwBufferSize)) {
      reportWindowsError("Querying options");
      goto cleanup;
    }
    // we turn pac off only if the option is set and pac url equals what provided
    if ((options.pOptions[0].Value.dwValue & PROXY_TYPE_AUTO_PROXY_URL) != PROXY_TYPE_AUTO_PROXY_URL
      || options.pOptions[1].Value.pszValue == NULL
      || strcmp(pacUrl, options.pOptions[1].Value.pszValue) != 0) {
      goto cleanup;
    }
    // fall through
turnOff:
    options.pOptions[0].Value.dwValue = PROXY_TYPE_DIRECT;
    options.pOptions[1].Value.pszValue = "";
  }

  BOOL result;
  result = InternetSetOption(NULL,INTERNET_OPTION_PER_CONNECTION_OPTION, &options, dwBufferSize);
  if (!result) {
    reportWindowsError("setting options");
    ret = SYSCALL_FAILED;
    goto cleanup;
  }
  result = InternetSetOption(NULL, INTERNET_OPTION_SETTINGS_CHANGED, NULL, 0);
  if (!result) {
    reportWindowsError("propagating changes");
    ret = SYSCALL_FAILED;
    goto cleanup;
  }
  result = InternetSetOption(NULL, INTERNET_OPTION_REFRESH , NULL, 0);
  if (!result) {
    reportWindowsError("refreshing");
    ret = SYSCALL_FAILED;
    goto cleanup;
  }

cleanup:
  free(options.pOptions);
  return ret;
}
