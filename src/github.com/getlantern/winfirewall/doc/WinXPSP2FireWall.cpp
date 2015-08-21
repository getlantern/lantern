// these uuids are not defined by mingw yet. If there is a compiler error in the future, please remove this lines and create an issue on github :)
#ifdef __MINGW32__
  #include <initguid.h>
  DEFINE_GUID(IID_INetFwAuthorizedApplication,      0xb5e64ffa, 0xc2c5, 0x444e, 0xa3, 0x01, 0xfb, 0x5e, 0x00, 0x01, 0x80, 0x50);
  DEFINE_GUID(IID_INetFwMgr,                        0xf7898af5, 0xcac4, 0x4632, 0xa2, 0xec, 0xda, 0x06, 0xe5, 0x11, 0x1a, 0xf2);
  DEFINE_GUID(IID_INetFwOpenPort,                   0xe0483ba0, 0x47ff, 0x4d9c, 0xa6, 0xd6, 0x77, 0x41, 0xd0, 0xb1, 0x95, 0xf7);

  DEFINE_GUID(CLSID_NetFwAuthorizedApplication,     0xec9846b3, 0x2762, 0x4a6b, 0xa2, 0x14, 0x6a, 0xcb, 0x60, 0x34, 0x62, 0xd2);
  DEFINE_GUID(CLSID_NetFwMgr,                       0x304ce942, 0x6e39, 0x40d8, 0x94, 0x3a, 0xb9, 0x13, 0xc4, 0x0c, 0x9c, 0xd4);
  DEFINE_GUID(CLSID_NetFwOpenPort,                  0x0ca545c6, 0x37ad, 0x4a6c, 0xbf, 0x92, 0x9f, 0x76, 0x10, 0x06, 0x7e, 0xf5);
#endif

#include "winxpsp2firewall.h"

WinXPSP2FireWall::WinXPSP2FireWall(void)
{
	m_pFireWallProfile = NULL;
}

WinXPSP2FireWall::~WinXPSP2FireWall(void)
{
	Uninitialize();
}

FW_ERROR_CODE WinXPSP2FireWall::Initialize()
{
	HRESULT hr = S_FALSE;
	INetFwMgr* fwMgr = NULL;
	INetFwPolicy* fwPolicy = NULL;

	FW_ERROR_CODE ret = FW_NOERROR;
	try
	{
		if( m_pFireWallProfile )
			throw FW_ERR_INITIALIZED;

		// Create an instance of the firewall settings manager.
		hr = CoCreateInstance( CLSID_NetFwMgr, NULL, CLSCTX_INPROC_SERVER, IID_INetFwMgr, (void**)&fwMgr );

		if( FAILED( hr ))
			throw FW_ERR_CREATE_SETTING_MANAGER;

		// Retrieve the local firewall policy.
		hr = fwMgr->get_LocalPolicy( &fwPolicy );
		if( FAILED( hr ))
			throw FW_ERR_LOCAL_POLICY;

		// Retrieve the firewall profile currently in effect
		hr = fwPolicy->get_CurrentProfile( &m_pFireWallProfile );
		if( FAILED( hr ))
			throw FW_ERR_PROFILE;

	}
	catch( FW_ERROR_CODE nError)
	{
		ret = nError;
	}

	if( fwPolicy )
		fwPolicy->Release();
	if( fwMgr )
		fwMgr->Release();

	return ret;
}

FW_ERROR_CODE WinXPSP2FireWall::Uninitialize()
{
	// Release the firewall profile
	if( m_pFireWallProfile )
	{
		m_pFireWallProfile->Release();
		m_pFireWallProfile = NULL;
	}

	return FW_NOERROR;
}

FW_ERROR_CODE WinXPSP2FireWall::IsWindowsFirewallOn( BOOL& bOn )
{
	HRESULT hr;
	VARIANT_BOOL bFWEnabled;
	bOn = FALSE;

	try
	{
		if( m_pFireWallProfile == NULL )
			throw FW_ERR_INITIALIZED;

		hr = m_pFireWallProfile->get_FirewallEnabled( &bFWEnabled );
		if( FAILED(hr))
			throw FW_ERR_FIREWALL_IS_ENABLED;

		if( bFWEnabled != VARIANT_FALSE )
			bOn = TRUE;
	}
	catch( FW_ERROR_CODE nError )
	{
		return nError;
	}

	return FW_NOERROR;
}

FW_ERROR_CODE WinXPSP2FireWall::TurnOnWindowsFirewall()
{
	HRESULT hr;

	try
	{
		if( m_pFireWallProfile == NULL )
			throw FW_ERR_INITIALIZED;

		// Check whether the firewall is off
		BOOL bFWOn;
		FW_ERROR_CODE ret = IsWindowsFirewallOn( bFWOn );

		if( ret != FW_NOERROR )
			throw ret;

		// If it is off now, turn it on
		if( !bFWOn )
		{
			hr = m_pFireWallProfile->put_FirewallEnabled( VARIANT_TRUE );
			if( FAILED( hr ))
				throw FW_ERR_FIREWALL_ENABLED;
		}
	}
	catch( FW_ERROR_CODE nError )
	{
		return nError;
	}

	return FW_NOERROR;
}

FW_ERROR_CODE WinXPSP2FireWall::TurnOffWindowsFirewall()
{
	HRESULT hr;
	try
	{
		if( m_pFireWallProfile == NULL )
			throw FW_ERR_INITIALIZED;

		// Check whether the firewall is off
		BOOL bFWOn;
		FW_ERROR_CODE ret = IsWindowsFirewallOn( bFWOn );

		if( ret != FW_NOERROR )
			throw ret;

		// If it is on now, turn it off
		if( bFWOn )
		{
			hr = m_pFireWallProfile->put_FirewallEnabled( VARIANT_FALSE );
			if( FAILED( hr ))
				throw FW_ERR_FIREWALL_ENABLED;
		}
	}
	catch( FW_ERROR_CODE nError )
	{
		return nError;
	}
	return FW_NOERROR;
}

FW_ERROR_CODE WinXPSP2FireWall::IsAppEnabled( const wchar_t* lpszProcessImageFileName, BOOL& bEnable )
{
	FW_ERROR_CODE ret = FW_NOERROR;
	HRESULT hr;
	BSTR bstrFWProcessImageFileName = NULL;
	VARIANT_BOOL bFWEnabled;
	INetFwAuthorizedApplication* pFWApp = NULL;
	INetFwAuthorizedApplications* pFWApps = NULL;
	
	bEnable = FALSE;
	try
	{
		if( m_pFireWallProfile == NULL )
			throw FW_ERR_INITIALIZED;

		if( lpszProcessImageFileName == NULL )
			throw FW_ERR_INVALID_ARG;

		hr = m_pFireWallProfile->get_AuthorizedApplications( &pFWApps );
		if( FAILED( hr ))
			throw FW_ERR_AUTH_APPLICATIONS;

		// Allocate a BSTR for the process image file name
		bstrFWProcessImageFileName = SysAllocString( lpszProcessImageFileName );
		if( SysStringLen( bstrFWProcessImageFileName ) == 0)
			throw FW_ERR_SYS_ALLOC_STRING;

		hr = pFWApps->Item( bstrFWProcessImageFileName, &pFWApp);
		// If FAILED, the appliacation is not in the collection list
		if( SUCCEEDED( hr ))
		{
			// Find out if the authorized application is enabled
			hr = pFWApp->get_Enabled( &bFWEnabled );

			if( FAILED( hr ))
				throw FW_ERR_APP_ENABLED;

			if( bFWEnabled == VARIANT_TRUE )
				bEnable = TRUE;
		}
	}
	catch( FW_ERROR_CODE nError )
	{
		ret = nError;
	}
	
	// Free the BSTR
	SysFreeString( bstrFWProcessImageFileName );

	// Release memories to retrieve the information of the application
	if( pFWApp )
		pFWApp->Release();
	if( pFWApps )
		pFWApps->Release();

	return ret;
}

FW_ERROR_CODE WinXPSP2FireWall::AddApplication( const wchar_t* lpszProcessImageFileName, const wchar_t* lpszRegisterName )
{
	FW_ERROR_CODE ret = FW_NOERROR;
	HRESULT hr;
	BOOL bAppEnable;
	BSTR bstrProcessImageFileName = NULL;
	BSTR bstrRegisterName = NULL;
	INetFwAuthorizedApplication* pFWApp = NULL;
	INetFwAuthorizedApplications* pFWApps = NULL;

	try
	{
		if( m_pFireWallProfile == NULL )
			throw FW_ERR_INITIALIZED;
		if( lpszProcessImageFileName == NULL || lpszRegisterName  == NULL )
			throw FW_ERR_INVALID_ARG;

		// First of all, check the application is already authorized;
		FW_ERROR_CODE  nError = this->IsAppEnabled( lpszProcessImageFileName, bAppEnable );
		if( nError != FW_NOERROR )
			throw nError;

		// Only add the application if it isn't authorized
		if( bAppEnable == FALSE )
		{
			// Retrieve the authorized application collection
			hr = m_pFireWallProfile->get_AuthorizedApplications( &pFWApps );
			if( FAILED( hr ))
				throw FW_ERR_AUTH_APPLICATIONS;

			// Create an instance of an authorized application
			hr = CoCreateInstance( CLSID_NetFwAuthorizedApplication, NULL, CLSCTX_INPROC_SERVER, IID_INetFwAuthorizedApplication, (void**)&pFWApp);
			if( FAILED( hr ))
				throw FW_ERR_CREATE_APP_INSTANCE;

			// Allocate a BSTR for the Process Image FileName
			bstrProcessImageFileName = SysAllocString( lpszProcessImageFileName );
			if( SysStringLen( bstrProcessImageFileName ) == 0)
				throw FW_ERR_SYS_ALLOC_STRING;

			// Set the process image file name
			hr = pFWApp->put_ProcessImageFileName( bstrProcessImageFileName );
			if( FAILED( hr ) )
				throw FW_ERR_PUT_PROCESS_IMAGE_NAME;

			// Allocate a BSTR for register name
			bstrRegisterName = SysAllocString( lpszRegisterName );
			if( SysStringLen( bstrRegisterName ) == 0)
				throw FW_ERR_SYS_ALLOC_STRING;
			// Set a registered name of the process
			hr = pFWApp->put_Name( bstrRegisterName );
			if( FAILED( hr ))
				throw FW_ERR_PUT_REGISTER_NAME;
			
			// Add the application to the collection
			hr = pFWApps->Add( pFWApp );
			if( FAILED( hr ))
				throw FW_ERR_ADD_TO_COLLECTION;
		}
	}
	catch( FW_ERROR_CODE nError )
	{
		ret = nError;
	}

	SysFreeString( bstrProcessImageFileName );
	SysFreeString( bstrRegisterName );

	if( pFWApp )
		pFWApp->Release();
	if( pFWApps )
		pFWApps->Release();

	return ret;
}

FW_ERROR_CODE WinXPSP2FireWall::RemoveApplication( const wchar_t* lpszProcessImageFileName )
{
	FW_ERROR_CODE ret = FW_NOERROR;
	HRESULT hr;
	BOOL bAppEnable;
	BSTR bstrProcessImageFileName = NULL;
	INetFwAuthorizedApplications* pFWApps = NULL;

	try
	{
		if( m_pFireWallProfile == NULL )
			throw FW_ERR_INITIALIZED;
		if( lpszProcessImageFileName == NULL )
			throw FW_ERR_INVALID_ARG;

		FW_ERROR_CODE  nError = this->IsAppEnabled( lpszProcessImageFileName, bAppEnable );
		if( nError != FW_NOERROR )
			throw nError;

		// Only remove the application if it is authorized
		if( bAppEnable == TRUE )
		{
			// Retrieve the authorized application collection
			hr = m_pFireWallProfile->get_AuthorizedApplications( &pFWApps );
			if( FAILED( hr ))
				throw FW_ERR_AUTH_APPLICATIONS;

			// Allocate a BSTR for the Process Image FileName
			bstrProcessImageFileName = SysAllocString( lpszProcessImageFileName );
			if( SysStringLen( bstrProcessImageFileName ) == 0)
				throw FW_ERR_SYS_ALLOC_STRING;
			hr = pFWApps->Remove( bstrProcessImageFileName );
			if( FAILED( hr ))
				throw FW_ERR_REMOVE_FROM_COLLECTION;
		}
	}
	catch( FW_ERROR_CODE nError)
	{
		ret = nError;
	}

	SysFreeString( bstrProcessImageFileName);
	if( pFWApps )
		pFWApps->Release();

	return ret;
}
FW_ERROR_CODE WinXPSP2FireWall::IsPortEnabled( LONG lPortNumber, NET_FW_IP_PROTOCOL ipProtocol, BOOL& bEnable )
{
	FW_ERROR_CODE ret = FW_NOERROR;
	VARIANT_BOOL bFWEnabled;
	INetFwOpenPort* pFWOpenPort = NULL;
	INetFwOpenPorts* pFWOpenPorts = NULL;
	HRESULT hr;

	bEnable = FALSE;
	try
	{
		if( m_pFireWallProfile == NULL )
			throw FW_ERR_INITIALIZED;

		// Retrieve the open ports collection
		hr = m_pFireWallProfile->get_GloballyOpenPorts( &pFWOpenPorts );
		if( FAILED( hr ))
			throw FW_ERR_GLOBAL_OPEN_PORTS;

		// Get the open port
		hr = pFWOpenPorts->Item( lPortNumber, ipProtocol, &pFWOpenPort );
		if( SUCCEEDED( hr ))
		{
			hr = pFWOpenPort->get_Enabled( &bFWEnabled );
			if( FAILED( hr ))
				throw FW_ERR_PORT_IS_ENABLED;

			if( bFWEnabled == VARIANT_TRUE )
				bEnable = TRUE;
		}
	}
	catch( FW_ERROR_CODE nError)
	{
		ret = nError;
	}

	if( pFWOpenPort )
		pFWOpenPort->Release();
	if( pFWOpenPorts )
		pFWOpenPorts->Release();

	return ret;
}

FW_ERROR_CODE WinXPSP2FireWall::AddPort( LONG lPortNumber, NET_FW_IP_PROTOCOL ipProtocol, const wchar_t* lpszRegisterName )
{
	FW_ERROR_CODE ret = FW_NOERROR;
	INetFwOpenPort* pFWOpenPort = NULL;
	INetFwOpenPorts* pFWOpenPorts = NULL;
	BSTR bstrRegisterName = NULL;
	HRESULT hr;

	try
	{
		if( m_pFireWallProfile == NULL )
			throw FW_ERR_INITIALIZED;
		BOOL bEnablePort;
		FW_ERROR_CODE nError = IsPortEnabled( lPortNumber, ipProtocol, bEnablePort);
		if( nError != FW_NOERROR)
			throw nError;

		// Only add the port, if it isn't added to the collection
		if( bEnablePort == FALSE )
		{
			// Retrieve the collection of globally open ports
			hr = m_pFireWallProfile->get_GloballyOpenPorts( &pFWOpenPorts );
			if( FAILED( hr ))
				throw FW_ERR_GLOBAL_OPEN_PORTS;

			// Create an instance of an open port
			hr = CoCreateInstance( CLSID_NetFwOpenPort, NULL, CLSCTX_INPROC_SERVER, IID_INetFwOpenPort, (void**)&pFWOpenPort);
			if( FAILED( hr ))
				throw FW_ERR_CREATE_PORT_INSTANCE;

			// Set the port number
			hr = pFWOpenPort->put_Port( lPortNumber );
			if( FAILED( hr ))
				throw FW_ERR_SET_PORT_NUMBER;

			// Set the IP Protocol
			hr = pFWOpenPort->put_Protocol( ipProtocol );
			if( FAILED( hr ))
				throw FW_ERR_SET_IP_PROTOCOL;

			bstrRegisterName = SysAllocString( lpszRegisterName );
			if( SysStringLen( bstrRegisterName ) == 0)
				throw FW_ERR_SYS_ALLOC_STRING;
		
			// Set the registered name
			hr = pFWOpenPort->put_Name( bstrRegisterName );
			if( FAILED( hr ))
				throw FW_ERR_PUT_REGISTER_NAME;

			hr = pFWOpenPorts->Add( pFWOpenPort );
			if( FAILED( hr ))
				throw FW_ERR_ADD_TO_COLLECTION;
		}

	}
	catch( FW_ERROR_CODE nError)
	{
		ret = nError;
	}

	SysFreeString( bstrRegisterName );
	if( pFWOpenPort )
		pFWOpenPort->Release();
	if( pFWOpenPorts )
		pFWOpenPorts->Release();

	return ret;
}

FW_ERROR_CODE WinXPSP2FireWall::RemovePort( LONG lPortNumber, NET_FW_IP_PROTOCOL ipProtocol )
{
	FW_ERROR_CODE ret = FW_NOERROR;
	INetFwOpenPorts* pFWOpenPorts = NULL;
	HRESULT hr;

	try
	{
		if( m_pFireWallProfile == NULL )
			throw FW_ERR_INITIALIZED;
		BOOL bEnablePort;
		FW_ERROR_CODE nError = IsPortEnabled( lPortNumber, ipProtocol, bEnablePort);
		if( nError != FW_NOERROR)
			throw nError;

		// Only remove the port, if it is on the collection
		if( bEnablePort == TRUE )
		{
			// Retrieve the collection of globally open ports
			hr = m_pFireWallProfile->get_GloballyOpenPorts( &pFWOpenPorts );
			if( FAILED( hr ))
				throw FW_ERR_GLOBAL_OPEN_PORTS;

			hr = pFWOpenPorts->Remove( lPortNumber, ipProtocol );
			if (FAILED( hr ))
				throw FW_ERR_REMOVE_FROM_COLLECTION;
		}

	}
	catch( FW_ERROR_CODE nError)
	{
		ret = nError;
	}

	if( pFWOpenPorts )
		pFWOpenPorts->Release();

	return ret;
}

FW_ERROR_CODE WinXPSP2FireWall::IsExceptionNotAllowed( BOOL& bNotAllowed )
{
	FW_ERROR_CODE ret = FW_NOERROR;

	bNotAllowed = TRUE;

	try
	{
		if( m_pFireWallProfile == NULL )
			throw FW_ERR_INITIALIZED;

		VARIANT_BOOL bExNotAllowed;

		HRESULT hr = m_pFireWallProfile->get_ExceptionsNotAllowed( &bExNotAllowed );
		
		if( FAILED( hr ))
			throw FW_ERR_EXCEPTION_NOT_ALLOWED;
		
		if( bExNotAllowed == VARIANT_TRUE )
			bNotAllowed = TRUE;
		else
			bNotAllowed = FALSE;
	}
	catch( FW_ERROR_CODE nError)
	{
		ret = nError;
	}

	return ret;
}

FW_ERROR_CODE WinXPSP2FireWall::SetExceptionNotAllowed( BOOL bNotAllowed )
{
	FW_ERROR_CODE ret = FW_NOERROR;

	try
	{
		if( m_pFireWallProfile == NULL )
			throw FW_ERR_INITIALIZED;
		HRESULT hr = m_pFireWallProfile->put_ExceptionsNotAllowed( bNotAllowed ? VARIANT_TRUE : VARIANT_FALSE );

		if( FAILED( hr ))
			throw FW_ERR_EXCEPTION_NOT_ALLOWED;
	}
	catch( FW_ERROR_CODE nError)
	{
		ret = nError;
	}

	return ret;
}

FW_ERROR_CODE WinXPSP2FireWall::IsNotificationDiabled( BOOL& bDisabled )
{
	FW_ERROR_CODE ret = FW_NOERROR;

	bDisabled = FALSE;
	try
	{
		if( m_pFireWallProfile == NULL )
			throw FW_ERR_INITIALIZED;

		VARIANT_BOOL bNotifyDisable;
		HRESULT hr = m_pFireWallProfile->get_NotificationsDisabled( &bNotifyDisable );
		if( FAILED( hr ))
			throw FW_ERR_NOTIFICATION_DISABLED;
		
		if( bNotifyDisable == VARIANT_TRUE )
			bDisabled = TRUE;
		else
			bDisabled = FALSE;
	}
	catch( FW_ERROR_CODE nError)
	{
		ret = nError;
	}

	return ret;
}

FW_ERROR_CODE WinXPSP2FireWall::SetNotificationDiabled( BOOL bDisabled )
{
	FW_ERROR_CODE ret = FW_NOERROR;

	try
	{
		if( m_pFireWallProfile == NULL )
			throw FW_ERR_INITIALIZED;

		HRESULT hr = m_pFireWallProfile->put_NotificationsDisabled( bDisabled ? VARIANT_TRUE : VARIANT_FALSE );
		if( FAILED( hr ))
			throw FW_ERR_NOTIFICATION_DISABLED;
	}
	catch( FW_ERROR_CODE nError)
	{
		ret = nError;
	}

	return ret;
}

FW_ERROR_CODE WinXPSP2FireWall::IsUnicastResponsesToMulticastBroadcastDisabled( BOOL& bDisabled )
{
	FW_ERROR_CODE ret = FW_NOERROR;

	bDisabled = FALSE;
	try
	{
		if( m_pFireWallProfile == NULL )
			throw FW_ERR_INITIALIZED;

		VARIANT_BOOL bUniMultiDisabled;
		HRESULT hr = m_pFireWallProfile->get_UnicastResponsesToMulticastBroadcastDisabled( &bUniMultiDisabled );
		if( FAILED( hr ))
			throw FW_ERR_UNICAST_MULTICAST;

		if( bUniMultiDisabled == VARIANT_TRUE )
			bDisabled = TRUE;
		else
			bDisabled = FALSE;
	}
	catch( FW_ERROR_CODE nError)
	{
		ret = nError;
	}

	return ret;
}

FW_ERROR_CODE WinXPSP2FireWall::SetUnicastResponsesToMulticastBroadcastDisabled( BOOL bDisabled )
{
	FW_ERROR_CODE ret = FW_NOERROR;

	try
	{
		if( m_pFireWallProfile == NULL )
			throw FW_ERR_INITIALIZED;

		HRESULT hr = m_pFireWallProfile->put_UnicastResponsesToMulticastBroadcastDisabled( bDisabled ? VARIANT_TRUE : VARIANT_FALSE );
		if( FAILED( hr ))
			throw FW_ERR_UNICAST_MULTICAST;
	}
	catch( FW_ERROR_CODE nError)
	{
		ret = nError;
	}

	return ret;
}
