

/* this ALWAYS GENERATED file contains the definitions for the interfaces */


 /* File created by MIDL compiler version 6.00.0366 */
/* Compiler settings for netfw.idl:
    Oicf, W1, Zp8, env=Win32 (32b run)
    protocol : dce , ms_ext, c_ext, robust
    error checks: allocation ref bounds_check enum stub_data 
    VC __declspec() decoration level: 
         __declspec(uuid()), __declspec(selectany), __declspec(novtable)
         DECLSPEC_UUID(), MIDL_INTERFACE()
*/
//@@MIDL_FILE_HEADING(  )

#pragma warning( disable: 4049 )  /* more than 64k source lines */


/* verify that the <rpcndr.h> version is high enough to compile this file*/
#ifndef __REQUIRED_RPCNDR_H_VERSION__
#define __REQUIRED_RPCNDR_H_VERSION__ 475
#endif

#include "rpc.h"
#include "rpcndr.h"

#ifndef __RPCNDR_H_VERSION__
#error this stub requires an updated version of <rpcndr.h>
#endif // __RPCNDR_H_VERSION__

#ifndef COM_NO_WINDOWS_H
#include "windows.h"
#include "ole2.h"
#endif /*COM_NO_WINDOWS_H*/

#ifndef __netfw_h__
#define __netfw_h__

#if defined(_MSC_VER) && (_MSC_VER >= 1020)
#pragma once
#endif

/* Forward Declarations */ 

#ifndef __INetFwRemoteAdminSettings_FWD_DEFINED__
#define __INetFwRemoteAdminSettings_FWD_DEFINED__
typedef interface INetFwRemoteAdminSettings INetFwRemoteAdminSettings;
#endif 	/* __INetFwRemoteAdminSettings_FWD_DEFINED__ */


#ifndef __INetFwIcmpSettings_FWD_DEFINED__
#define __INetFwIcmpSettings_FWD_DEFINED__
typedef interface INetFwIcmpSettings INetFwIcmpSettings;
#endif 	/* __INetFwIcmpSettings_FWD_DEFINED__ */


#ifndef __INetFwOpenPort_FWD_DEFINED__
#define __INetFwOpenPort_FWD_DEFINED__
typedef interface INetFwOpenPort INetFwOpenPort;
#endif 	/* __INetFwOpenPort_FWD_DEFINED__ */


#ifndef __INetFwOpenPorts_FWD_DEFINED__
#define __INetFwOpenPorts_FWD_DEFINED__
typedef interface INetFwOpenPorts INetFwOpenPorts;
#endif 	/* __INetFwOpenPorts_FWD_DEFINED__ */


#ifndef __INetFwService_FWD_DEFINED__
#define __INetFwService_FWD_DEFINED__
typedef interface INetFwService INetFwService;
#endif 	/* __INetFwService_FWD_DEFINED__ */


#ifndef __INetFwServices_FWD_DEFINED__
#define __INetFwServices_FWD_DEFINED__
typedef interface INetFwServices INetFwServices;
#endif 	/* __INetFwServices_FWD_DEFINED__ */


#ifndef __INetFwAuthorizedApplication_FWD_DEFINED__
#define __INetFwAuthorizedApplication_FWD_DEFINED__
typedef interface INetFwAuthorizedApplication INetFwAuthorizedApplication;
#endif 	/* __INetFwAuthorizedApplication_FWD_DEFINED__ */


#ifndef __INetFwAuthorizedApplications_FWD_DEFINED__
#define __INetFwAuthorizedApplications_FWD_DEFINED__
typedef interface INetFwAuthorizedApplications INetFwAuthorizedApplications;
#endif 	/* __INetFwAuthorizedApplications_FWD_DEFINED__ */


#ifndef __INetFwProfile_FWD_DEFINED__
#define __INetFwProfile_FWD_DEFINED__
typedef interface INetFwProfile INetFwProfile;
#endif 	/* __INetFwProfile_FWD_DEFINED__ */


#ifndef __INetFwPolicy_FWD_DEFINED__
#define __INetFwPolicy_FWD_DEFINED__
typedef interface INetFwPolicy INetFwPolicy;
#endif 	/* __INetFwPolicy_FWD_DEFINED__ */


#ifndef __INetFwMgr_FWD_DEFINED__
#define __INetFwMgr_FWD_DEFINED__
typedef interface INetFwMgr INetFwMgr;
#endif 	/* __INetFwMgr_FWD_DEFINED__ */


#ifndef __INetFwRemoteAdminSettings_FWD_DEFINED__
#define __INetFwRemoteAdminSettings_FWD_DEFINED__
typedef interface INetFwRemoteAdminSettings INetFwRemoteAdminSettings;
#endif 	/* __INetFwRemoteAdminSettings_FWD_DEFINED__ */


#ifndef __INetFwIcmpSettings_FWD_DEFINED__
#define __INetFwIcmpSettings_FWD_DEFINED__
typedef interface INetFwIcmpSettings INetFwIcmpSettings;
#endif 	/* __INetFwIcmpSettings_FWD_DEFINED__ */


#ifndef __INetFwOpenPort_FWD_DEFINED__
#define __INetFwOpenPort_FWD_DEFINED__
typedef interface INetFwOpenPort INetFwOpenPort;
#endif 	/* __INetFwOpenPort_FWD_DEFINED__ */


#ifndef __INetFwOpenPorts_FWD_DEFINED__
#define __INetFwOpenPorts_FWD_DEFINED__
typedef interface INetFwOpenPorts INetFwOpenPorts;
#endif 	/* __INetFwOpenPorts_FWD_DEFINED__ */


#ifndef __INetFwService_FWD_DEFINED__
#define __INetFwService_FWD_DEFINED__
typedef interface INetFwService INetFwService;
#endif 	/* __INetFwService_FWD_DEFINED__ */


#ifndef __INetFwServices_FWD_DEFINED__
#define __INetFwServices_FWD_DEFINED__
typedef interface INetFwServices INetFwServices;
#endif 	/* __INetFwServices_FWD_DEFINED__ */


#ifndef __INetFwAuthorizedApplication_FWD_DEFINED__
#define __INetFwAuthorizedApplication_FWD_DEFINED__
typedef interface INetFwAuthorizedApplication INetFwAuthorizedApplication;
#endif 	/* __INetFwAuthorizedApplication_FWD_DEFINED__ */


#ifndef __INetFwAuthorizedApplications_FWD_DEFINED__
#define __INetFwAuthorizedApplications_FWD_DEFINED__
typedef interface INetFwAuthorizedApplications INetFwAuthorizedApplications;
#endif 	/* __INetFwAuthorizedApplications_FWD_DEFINED__ */


#ifndef __INetFwProfile_FWD_DEFINED__
#define __INetFwProfile_FWD_DEFINED__
typedef interface INetFwProfile INetFwProfile;
#endif 	/* __INetFwProfile_FWD_DEFINED__ */


#ifndef __INetFwPolicy_FWD_DEFINED__
#define __INetFwPolicy_FWD_DEFINED__
typedef interface INetFwPolicy INetFwPolicy;
#endif 	/* __INetFwPolicy_FWD_DEFINED__ */


#ifndef __INetFwMgr_FWD_DEFINED__
#define __INetFwMgr_FWD_DEFINED__
typedef interface INetFwMgr INetFwMgr;
#endif 	/* __INetFwMgr_FWD_DEFINED__ */


#ifndef __NetFwOpenPort_FWD_DEFINED__
#define __NetFwOpenPort_FWD_DEFINED__

#ifdef __cplusplus
typedef class NetFwOpenPort NetFwOpenPort;
#else
typedef struct NetFwOpenPort NetFwOpenPort;
#endif /* __cplusplus */

#endif 	/* __NetFwOpenPort_FWD_DEFINED__ */


#ifndef __NetFwAuthorizedApplication_FWD_DEFINED__
#define __NetFwAuthorizedApplication_FWD_DEFINED__

#ifdef __cplusplus
typedef class NetFwAuthorizedApplication NetFwAuthorizedApplication;
#else
typedef struct NetFwAuthorizedApplication NetFwAuthorizedApplication;
#endif /* __cplusplus */

#endif 	/* __NetFwAuthorizedApplication_FWD_DEFINED__ */


#ifndef __NetFwMgr_FWD_DEFINED__
#define __NetFwMgr_FWD_DEFINED__

#ifdef __cplusplus
typedef class NetFwMgr NetFwMgr;
#else
typedef struct NetFwMgr NetFwMgr;
#endif /* __cplusplus */

#endif 	/* __NetFwMgr_FWD_DEFINED__ */


/* header files for imported files */
#include "icftypes.h"
#include "oaidl.h"

#ifdef __cplusplus
extern "C"{
#endif 

void * __RPC_USER MIDL_user_allocate(size_t);
void __RPC_USER MIDL_user_free( void * ); 

#ifndef __INetFwRemoteAdminSettings_INTERFACE_DEFINED__
#define __INetFwRemoteAdminSettings_INTERFACE_DEFINED__

/* interface INetFwRemoteAdminSettings */
/* [dual][uuid][object] */ 


EXTERN_C const IID IID_INetFwRemoteAdminSettings;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("D4BECDDF-6F73-4A83-B832-9C66874CD20E")
    INetFwRemoteAdminSettings : public IDispatch
    {
    public:
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_IpVersion( 
            /* [retval][out] */ NET_FW_IP_VERSION *ipVersion) = 0;
        
        virtual /* [propput][id] */ HRESULT STDMETHODCALLTYPE put_IpVersion( 
            /* [in] */ NET_FW_IP_VERSION ipVersion) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_Scope( 
            /* [retval][out] */ NET_FW_SCOPE *scope) = 0;
        
        virtual /* [propput][id] */ HRESULT STDMETHODCALLTYPE put_Scope( 
            /* [in] */ NET_FW_SCOPE scope) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_RemoteAddresses( 
            /* [retval][out] */ BSTR *remoteAddrs) = 0;
        
        virtual /* [propput][id] */ HRESULT STDMETHODCALLTYPE put_RemoteAddresses( 
            /* [in] */ BSTR remoteAddrs) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_Enabled( 
            /* [retval][out] */ VARIANT_BOOL *enabled) = 0;
        
        virtual /* [propput][id] */ HRESULT STDMETHODCALLTYPE put_Enabled( 
            /* [in] */ VARIANT_BOOL enabled) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct INetFwRemoteAdminSettingsVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE *QueryInterface )( 
            INetFwRemoteAdminSettings * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void **ppvObject);
        
        ULONG ( STDMETHODCALLTYPE *AddRef )( 
            INetFwRemoteAdminSettings * This);
        
        ULONG ( STDMETHODCALLTYPE *Release )( 
            INetFwRemoteAdminSettings * This);
        
        HRESULT ( STDMETHODCALLTYPE *GetTypeInfoCount )( 
            INetFwRemoteAdminSettings * This,
            /* [out] */ UINT *pctinfo);
        
        HRESULT ( STDMETHODCALLTYPE *GetTypeInfo )( 
            INetFwRemoteAdminSettings * This,
            /* [in] */ UINT iTInfo,
            /* [in] */ LCID lcid,
            /* [out] */ ITypeInfo **ppTInfo);
        
        HRESULT ( STDMETHODCALLTYPE *GetIDsOfNames )( 
            INetFwRemoteAdminSettings * This,
            /* [in] */ REFIID riid,
            /* [size_is][in] */ LPOLESTR *rgszNames,
            /* [in] */ UINT cNames,
            /* [in] */ LCID lcid,
            /* [size_is][out] */ DISPID *rgDispId);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE *Invoke )( 
            INetFwRemoteAdminSettings * This,
            /* [in] */ DISPID dispIdMember,
            /* [in] */ REFIID riid,
            /* [in] */ LCID lcid,
            /* [in] */ WORD wFlags,
            /* [out][in] */ DISPPARAMS *pDispParams,
            /* [out] */ VARIANT *pVarResult,
            /* [out] */ EXCEPINFO *pExcepInfo,
            /* [out] */ UINT *puArgErr);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_IpVersion )( 
            INetFwRemoteAdminSettings * This,
            /* [retval][out] */ NET_FW_IP_VERSION *ipVersion);
        
        /* [propput][id] */ HRESULT ( STDMETHODCALLTYPE *put_IpVersion )( 
            INetFwRemoteAdminSettings * This,
            /* [in] */ NET_FW_IP_VERSION ipVersion);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_Scope )( 
            INetFwRemoteAdminSettings * This,
            /* [retval][out] */ NET_FW_SCOPE *scope);
        
        /* [propput][id] */ HRESULT ( STDMETHODCALLTYPE *put_Scope )( 
            INetFwRemoteAdminSettings * This,
            /* [in] */ NET_FW_SCOPE scope);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_RemoteAddresses )( 
            INetFwRemoteAdminSettings * This,
            /* [retval][out] */ BSTR *remoteAddrs);
        
        /* [propput][id] */ HRESULT ( STDMETHODCALLTYPE *put_RemoteAddresses )( 
            INetFwRemoteAdminSettings * This,
            /* [in] */ BSTR remoteAddrs);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_Enabled )( 
            INetFwRemoteAdminSettings * This,
            /* [retval][out] */ VARIANT_BOOL *enabled);
        
        /* [propput][id] */ HRESULT ( STDMETHODCALLTYPE *put_Enabled )( 
            INetFwRemoteAdminSettings * This,
            /* [in] */ VARIANT_BOOL enabled);
        
        END_INTERFACE
    } INetFwRemoteAdminSettingsVtbl;

    interface INetFwRemoteAdminSettings
    {
        CONST_VTBL struct INetFwRemoteAdminSettingsVtbl *lpVtbl;
    };

    

#ifdef COBJMACROS


#define INetFwRemoteAdminSettings_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define INetFwRemoteAdminSettings_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define INetFwRemoteAdminSettings_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define INetFwRemoteAdminSettings_GetTypeInfoCount(This,pctinfo)	\
    (This)->lpVtbl -> GetTypeInfoCount(This,pctinfo)

#define INetFwRemoteAdminSettings_GetTypeInfo(This,iTInfo,lcid,ppTInfo)	\
    (This)->lpVtbl -> GetTypeInfo(This,iTInfo,lcid,ppTInfo)

#define INetFwRemoteAdminSettings_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)	\
    (This)->lpVtbl -> GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)

#define INetFwRemoteAdminSettings_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)	\
    (This)->lpVtbl -> Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)


#define INetFwRemoteAdminSettings_get_IpVersion(This,ipVersion)	\
    (This)->lpVtbl -> get_IpVersion(This,ipVersion)

#define INetFwRemoteAdminSettings_put_IpVersion(This,ipVersion)	\
    (This)->lpVtbl -> put_IpVersion(This,ipVersion)

#define INetFwRemoteAdminSettings_get_Scope(This,scope)	\
    (This)->lpVtbl -> get_Scope(This,scope)

#define INetFwRemoteAdminSettings_put_Scope(This,scope)	\
    (This)->lpVtbl -> put_Scope(This,scope)

#define INetFwRemoteAdminSettings_get_RemoteAddresses(This,remoteAddrs)	\
    (This)->lpVtbl -> get_RemoteAddresses(This,remoteAddrs)

#define INetFwRemoteAdminSettings_put_RemoteAddresses(This,remoteAddrs)	\
    (This)->lpVtbl -> put_RemoteAddresses(This,remoteAddrs)

#define INetFwRemoteAdminSettings_get_Enabled(This,enabled)	\
    (This)->lpVtbl -> get_Enabled(This,enabled)

#define INetFwRemoteAdminSettings_put_Enabled(This,enabled)	\
    (This)->lpVtbl -> put_Enabled(This,enabled)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwRemoteAdminSettings_get_IpVersion_Proxy( 
    INetFwRemoteAdminSettings * This,
    /* [retval][out] */ NET_FW_IP_VERSION *ipVersion);


void __RPC_STUB INetFwRemoteAdminSettings_get_IpVersion_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][id] */ HRESULT STDMETHODCALLTYPE INetFwRemoteAdminSettings_put_IpVersion_Proxy( 
    INetFwRemoteAdminSettings * This,
    /* [in] */ NET_FW_IP_VERSION ipVersion);


void __RPC_STUB INetFwRemoteAdminSettings_put_IpVersion_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwRemoteAdminSettings_get_Scope_Proxy( 
    INetFwRemoteAdminSettings * This,
    /* [retval][out] */ NET_FW_SCOPE *scope);


void __RPC_STUB INetFwRemoteAdminSettings_get_Scope_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][id] */ HRESULT STDMETHODCALLTYPE INetFwRemoteAdminSettings_put_Scope_Proxy( 
    INetFwRemoteAdminSettings * This,
    /* [in] */ NET_FW_SCOPE scope);


void __RPC_STUB INetFwRemoteAdminSettings_put_Scope_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwRemoteAdminSettings_get_RemoteAddresses_Proxy( 
    INetFwRemoteAdminSettings * This,
    /* [retval][out] */ BSTR *remoteAddrs);


void __RPC_STUB INetFwRemoteAdminSettings_get_RemoteAddresses_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][id] */ HRESULT STDMETHODCALLTYPE INetFwRemoteAdminSettings_put_RemoteAddresses_Proxy( 
    INetFwRemoteAdminSettings * This,
    /* [in] */ BSTR remoteAddrs);


void __RPC_STUB INetFwRemoteAdminSettings_put_RemoteAddresses_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwRemoteAdminSettings_get_Enabled_Proxy( 
    INetFwRemoteAdminSettings * This,
    /* [retval][out] */ VARIANT_BOOL *enabled);


void __RPC_STUB INetFwRemoteAdminSettings_get_Enabled_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][id] */ HRESULT STDMETHODCALLTYPE INetFwRemoteAdminSettings_put_Enabled_Proxy( 
    INetFwRemoteAdminSettings * This,
    /* [in] */ VARIANT_BOOL enabled);


void __RPC_STUB INetFwRemoteAdminSettings_put_Enabled_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __INetFwRemoteAdminSettings_INTERFACE_DEFINED__ */


#ifndef __INetFwIcmpSettings_INTERFACE_DEFINED__
#define __INetFwIcmpSettings_INTERFACE_DEFINED__

/* interface INetFwIcmpSettings */
/* [dual][uuid][object] */ 


EXTERN_C const IID IID_INetFwIcmpSettings;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("A6207B2E-7CDD-426A-951E-5E1CBC5AFEAD")
    INetFwIcmpSettings : public IDispatch
    {
    public:
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_AllowOutboundDestinationUnreachable( 
            /* [retval][out] */ VARIANT_BOOL *allow) = 0;
        
        virtual /* [propput][id] */ HRESULT STDMETHODCALLTYPE put_AllowOutboundDestinationUnreachable( 
            /* [in] */ VARIANT_BOOL allow) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_AllowRedirect( 
            /* [retval][out] */ VARIANT_BOOL *allow) = 0;
        
        virtual /* [propput][id] */ HRESULT STDMETHODCALLTYPE put_AllowRedirect( 
            /* [in] */ VARIANT_BOOL allow) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_AllowInboundEchoRequest( 
            /* [retval][out] */ VARIANT_BOOL *allow) = 0;
        
        virtual /* [propput][id] */ HRESULT STDMETHODCALLTYPE put_AllowInboundEchoRequest( 
            /* [in] */ VARIANT_BOOL allow) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_AllowOutboundTimeExceeded( 
            /* [retval][out] */ VARIANT_BOOL *allow) = 0;
        
        virtual /* [propput][id] */ HRESULT STDMETHODCALLTYPE put_AllowOutboundTimeExceeded( 
            /* [in] */ VARIANT_BOOL allow) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_AllowOutboundParameterProblem( 
            /* [retval][out] */ VARIANT_BOOL *allow) = 0;
        
        virtual /* [propput][id] */ HRESULT STDMETHODCALLTYPE put_AllowOutboundParameterProblem( 
            /* [in] */ VARIANT_BOOL allow) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_AllowOutboundSourceQuench( 
            /* [retval][out] */ VARIANT_BOOL *allow) = 0;
        
        virtual /* [propput][id] */ HRESULT STDMETHODCALLTYPE put_AllowOutboundSourceQuench( 
            /* [in] */ VARIANT_BOOL allow) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_AllowInboundRouterRequest( 
            /* [retval][out] */ VARIANT_BOOL *allow) = 0;
        
        virtual /* [propput][id] */ HRESULT STDMETHODCALLTYPE put_AllowInboundRouterRequest( 
            /* [in] */ VARIANT_BOOL allow) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_AllowInboundTimestampRequest( 
            /* [retval][out] */ VARIANT_BOOL *allow) = 0;
        
        virtual /* [propput][id] */ HRESULT STDMETHODCALLTYPE put_AllowInboundTimestampRequest( 
            /* [in] */ VARIANT_BOOL allow) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_AllowInboundMaskRequest( 
            /* [retval][out] */ VARIANT_BOOL *allow) = 0;
        
        virtual /* [propput][id] */ HRESULT STDMETHODCALLTYPE put_AllowInboundMaskRequest( 
            /* [in] */ VARIANT_BOOL allow) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_AllowOutboundPacketTooBig( 
            /* [retval][out] */ VARIANT_BOOL *allow) = 0;
        
        virtual /* [propput][id] */ HRESULT STDMETHODCALLTYPE put_AllowOutboundPacketTooBig( 
            /* [in] */ VARIANT_BOOL allow) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct INetFwIcmpSettingsVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE *QueryInterface )( 
            INetFwIcmpSettings * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void **ppvObject);
        
        ULONG ( STDMETHODCALLTYPE *AddRef )( 
            INetFwIcmpSettings * This);
        
        ULONG ( STDMETHODCALLTYPE *Release )( 
            INetFwIcmpSettings * This);
        
        HRESULT ( STDMETHODCALLTYPE *GetTypeInfoCount )( 
            INetFwIcmpSettings * This,
            /* [out] */ UINT *pctinfo);
        
        HRESULT ( STDMETHODCALLTYPE *GetTypeInfo )( 
            INetFwIcmpSettings * This,
            /* [in] */ UINT iTInfo,
            /* [in] */ LCID lcid,
            /* [out] */ ITypeInfo **ppTInfo);
        
        HRESULT ( STDMETHODCALLTYPE *GetIDsOfNames )( 
            INetFwIcmpSettings * This,
            /* [in] */ REFIID riid,
            /* [size_is][in] */ LPOLESTR *rgszNames,
            /* [in] */ UINT cNames,
            /* [in] */ LCID lcid,
            /* [size_is][out] */ DISPID *rgDispId);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE *Invoke )( 
            INetFwIcmpSettings * This,
            /* [in] */ DISPID dispIdMember,
            /* [in] */ REFIID riid,
            /* [in] */ LCID lcid,
            /* [in] */ WORD wFlags,
            /* [out][in] */ DISPPARAMS *pDispParams,
            /* [out] */ VARIANT *pVarResult,
            /* [out] */ EXCEPINFO *pExcepInfo,
            /* [out] */ UINT *puArgErr);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_AllowOutboundDestinationUnreachable )( 
            INetFwIcmpSettings * This,
            /* [retval][out] */ VARIANT_BOOL *allow);
        
        /* [propput][id] */ HRESULT ( STDMETHODCALLTYPE *put_AllowOutboundDestinationUnreachable )( 
            INetFwIcmpSettings * This,
            /* [in] */ VARIANT_BOOL allow);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_AllowRedirect )( 
            INetFwIcmpSettings * This,
            /* [retval][out] */ VARIANT_BOOL *allow);
        
        /* [propput][id] */ HRESULT ( STDMETHODCALLTYPE *put_AllowRedirect )( 
            INetFwIcmpSettings * This,
            /* [in] */ VARIANT_BOOL allow);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_AllowInboundEchoRequest )( 
            INetFwIcmpSettings * This,
            /* [retval][out] */ VARIANT_BOOL *allow);
        
        /* [propput][id] */ HRESULT ( STDMETHODCALLTYPE *put_AllowInboundEchoRequest )( 
            INetFwIcmpSettings * This,
            /* [in] */ VARIANT_BOOL allow);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_AllowOutboundTimeExceeded )( 
            INetFwIcmpSettings * This,
            /* [retval][out] */ VARIANT_BOOL *allow);
        
        /* [propput][id] */ HRESULT ( STDMETHODCALLTYPE *put_AllowOutboundTimeExceeded )( 
            INetFwIcmpSettings * This,
            /* [in] */ VARIANT_BOOL allow);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_AllowOutboundParameterProblem )( 
            INetFwIcmpSettings * This,
            /* [retval][out] */ VARIANT_BOOL *allow);
        
        /* [propput][id] */ HRESULT ( STDMETHODCALLTYPE *put_AllowOutboundParameterProblem )( 
            INetFwIcmpSettings * This,
            /* [in] */ VARIANT_BOOL allow);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_AllowOutboundSourceQuench )( 
            INetFwIcmpSettings * This,
            /* [retval][out] */ VARIANT_BOOL *allow);
        
        /* [propput][id] */ HRESULT ( STDMETHODCALLTYPE *put_AllowOutboundSourceQuench )( 
            INetFwIcmpSettings * This,
            /* [in] */ VARIANT_BOOL allow);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_AllowInboundRouterRequest )( 
            INetFwIcmpSettings * This,
            /* [retval][out] */ VARIANT_BOOL *allow);
        
        /* [propput][id] */ HRESULT ( STDMETHODCALLTYPE *put_AllowInboundRouterRequest )( 
            INetFwIcmpSettings * This,
            /* [in] */ VARIANT_BOOL allow);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_AllowInboundTimestampRequest )( 
            INetFwIcmpSettings * This,
            /* [retval][out] */ VARIANT_BOOL *allow);
        
        /* [propput][id] */ HRESULT ( STDMETHODCALLTYPE *put_AllowInboundTimestampRequest )( 
            INetFwIcmpSettings * This,
            /* [in] */ VARIANT_BOOL allow);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_AllowInboundMaskRequest )( 
            INetFwIcmpSettings * This,
            /* [retval][out] */ VARIANT_BOOL *allow);
        
        /* [propput][id] */ HRESULT ( STDMETHODCALLTYPE *put_AllowInboundMaskRequest )( 
            INetFwIcmpSettings * This,
            /* [in] */ VARIANT_BOOL allow);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_AllowOutboundPacketTooBig )( 
            INetFwIcmpSettings * This,
            /* [retval][out] */ VARIANT_BOOL *allow);
        
        /* [propput][id] */ HRESULT ( STDMETHODCALLTYPE *put_AllowOutboundPacketTooBig )( 
            INetFwIcmpSettings * This,
            /* [in] */ VARIANT_BOOL allow);
        
        END_INTERFACE
    } INetFwIcmpSettingsVtbl;

    interface INetFwIcmpSettings
    {
        CONST_VTBL struct INetFwIcmpSettingsVtbl *lpVtbl;
    };

    

#ifdef COBJMACROS


#define INetFwIcmpSettings_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define INetFwIcmpSettings_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define INetFwIcmpSettings_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define INetFwIcmpSettings_GetTypeInfoCount(This,pctinfo)	\
    (This)->lpVtbl -> GetTypeInfoCount(This,pctinfo)

#define INetFwIcmpSettings_GetTypeInfo(This,iTInfo,lcid,ppTInfo)	\
    (This)->lpVtbl -> GetTypeInfo(This,iTInfo,lcid,ppTInfo)

#define INetFwIcmpSettings_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)	\
    (This)->lpVtbl -> GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)

#define INetFwIcmpSettings_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)	\
    (This)->lpVtbl -> Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)


#define INetFwIcmpSettings_get_AllowOutboundDestinationUnreachable(This,allow)	\
    (This)->lpVtbl -> get_AllowOutboundDestinationUnreachable(This,allow)

#define INetFwIcmpSettings_put_AllowOutboundDestinationUnreachable(This,allow)	\
    (This)->lpVtbl -> put_AllowOutboundDestinationUnreachable(This,allow)

#define INetFwIcmpSettings_get_AllowRedirect(This,allow)	\
    (This)->lpVtbl -> get_AllowRedirect(This,allow)

#define INetFwIcmpSettings_put_AllowRedirect(This,allow)	\
    (This)->lpVtbl -> put_AllowRedirect(This,allow)

#define INetFwIcmpSettings_get_AllowInboundEchoRequest(This,allow)	\
    (This)->lpVtbl -> get_AllowInboundEchoRequest(This,allow)

#define INetFwIcmpSettings_put_AllowInboundEchoRequest(This,allow)	\
    (This)->lpVtbl -> put_AllowInboundEchoRequest(This,allow)

#define INetFwIcmpSettings_get_AllowOutboundTimeExceeded(This,allow)	\
    (This)->lpVtbl -> get_AllowOutboundTimeExceeded(This,allow)

#define INetFwIcmpSettings_put_AllowOutboundTimeExceeded(This,allow)	\
    (This)->lpVtbl -> put_AllowOutboundTimeExceeded(This,allow)

#define INetFwIcmpSettings_get_AllowOutboundParameterProblem(This,allow)	\
    (This)->lpVtbl -> get_AllowOutboundParameterProblem(This,allow)

#define INetFwIcmpSettings_put_AllowOutboundParameterProblem(This,allow)	\
    (This)->lpVtbl -> put_AllowOutboundParameterProblem(This,allow)

#define INetFwIcmpSettings_get_AllowOutboundSourceQuench(This,allow)	\
    (This)->lpVtbl -> get_AllowOutboundSourceQuench(This,allow)

#define INetFwIcmpSettings_put_AllowOutboundSourceQuench(This,allow)	\
    (This)->lpVtbl -> put_AllowOutboundSourceQuench(This,allow)

#define INetFwIcmpSettings_get_AllowInboundRouterRequest(This,allow)	\
    (This)->lpVtbl -> get_AllowInboundRouterRequest(This,allow)

#define INetFwIcmpSettings_put_AllowInboundRouterRequest(This,allow)	\
    (This)->lpVtbl -> put_AllowInboundRouterRequest(This,allow)

#define INetFwIcmpSettings_get_AllowInboundTimestampRequest(This,allow)	\
    (This)->lpVtbl -> get_AllowInboundTimestampRequest(This,allow)

#define INetFwIcmpSettings_put_AllowInboundTimestampRequest(This,allow)	\
    (This)->lpVtbl -> put_AllowInboundTimestampRequest(This,allow)

#define INetFwIcmpSettings_get_AllowInboundMaskRequest(This,allow)	\
    (This)->lpVtbl -> get_AllowInboundMaskRequest(This,allow)

#define INetFwIcmpSettings_put_AllowInboundMaskRequest(This,allow)	\
    (This)->lpVtbl -> put_AllowInboundMaskRequest(This,allow)

#define INetFwIcmpSettings_get_AllowOutboundPacketTooBig(This,allow)	\
    (This)->lpVtbl -> get_AllowOutboundPacketTooBig(This,allow)

#define INetFwIcmpSettings_put_AllowOutboundPacketTooBig(This,allow)	\
    (This)->lpVtbl -> put_AllowOutboundPacketTooBig(This,allow)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwIcmpSettings_get_AllowOutboundDestinationUnreachable_Proxy( 
    INetFwIcmpSettings * This,
    /* [retval][out] */ VARIANT_BOOL *allow);


void __RPC_STUB INetFwIcmpSettings_get_AllowOutboundDestinationUnreachable_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][id] */ HRESULT STDMETHODCALLTYPE INetFwIcmpSettings_put_AllowOutboundDestinationUnreachable_Proxy( 
    INetFwIcmpSettings * This,
    /* [in] */ VARIANT_BOOL allow);


void __RPC_STUB INetFwIcmpSettings_put_AllowOutboundDestinationUnreachable_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwIcmpSettings_get_AllowRedirect_Proxy( 
    INetFwIcmpSettings * This,
    /* [retval][out] */ VARIANT_BOOL *allow);


void __RPC_STUB INetFwIcmpSettings_get_AllowRedirect_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][id] */ HRESULT STDMETHODCALLTYPE INetFwIcmpSettings_put_AllowRedirect_Proxy( 
    INetFwIcmpSettings * This,
    /* [in] */ VARIANT_BOOL allow);


void __RPC_STUB INetFwIcmpSettings_put_AllowRedirect_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwIcmpSettings_get_AllowInboundEchoRequest_Proxy( 
    INetFwIcmpSettings * This,
    /* [retval][out] */ VARIANT_BOOL *allow);


void __RPC_STUB INetFwIcmpSettings_get_AllowInboundEchoRequest_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][id] */ HRESULT STDMETHODCALLTYPE INetFwIcmpSettings_put_AllowInboundEchoRequest_Proxy( 
    INetFwIcmpSettings * This,
    /* [in] */ VARIANT_BOOL allow);


void __RPC_STUB INetFwIcmpSettings_put_AllowInboundEchoRequest_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwIcmpSettings_get_AllowOutboundTimeExceeded_Proxy( 
    INetFwIcmpSettings * This,
    /* [retval][out] */ VARIANT_BOOL *allow);


void __RPC_STUB INetFwIcmpSettings_get_AllowOutboundTimeExceeded_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][id] */ HRESULT STDMETHODCALLTYPE INetFwIcmpSettings_put_AllowOutboundTimeExceeded_Proxy( 
    INetFwIcmpSettings * This,
    /* [in] */ VARIANT_BOOL allow);


void __RPC_STUB INetFwIcmpSettings_put_AllowOutboundTimeExceeded_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwIcmpSettings_get_AllowOutboundParameterProblem_Proxy( 
    INetFwIcmpSettings * This,
    /* [retval][out] */ VARIANT_BOOL *allow);


void __RPC_STUB INetFwIcmpSettings_get_AllowOutboundParameterProblem_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][id] */ HRESULT STDMETHODCALLTYPE INetFwIcmpSettings_put_AllowOutboundParameterProblem_Proxy( 
    INetFwIcmpSettings * This,
    /* [in] */ VARIANT_BOOL allow);


void __RPC_STUB INetFwIcmpSettings_put_AllowOutboundParameterProblem_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwIcmpSettings_get_AllowOutboundSourceQuench_Proxy( 
    INetFwIcmpSettings * This,
    /* [retval][out] */ VARIANT_BOOL *allow);


void __RPC_STUB INetFwIcmpSettings_get_AllowOutboundSourceQuench_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][id] */ HRESULT STDMETHODCALLTYPE INetFwIcmpSettings_put_AllowOutboundSourceQuench_Proxy( 
    INetFwIcmpSettings * This,
    /* [in] */ VARIANT_BOOL allow);


void __RPC_STUB INetFwIcmpSettings_put_AllowOutboundSourceQuench_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwIcmpSettings_get_AllowInboundRouterRequest_Proxy( 
    INetFwIcmpSettings * This,
    /* [retval][out] */ VARIANT_BOOL *allow);


void __RPC_STUB INetFwIcmpSettings_get_AllowInboundRouterRequest_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][id] */ HRESULT STDMETHODCALLTYPE INetFwIcmpSettings_put_AllowInboundRouterRequest_Proxy( 
    INetFwIcmpSettings * This,
    /* [in] */ VARIANT_BOOL allow);


void __RPC_STUB INetFwIcmpSettings_put_AllowInboundRouterRequest_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwIcmpSettings_get_AllowInboundTimestampRequest_Proxy( 
    INetFwIcmpSettings * This,
    /* [retval][out] */ VARIANT_BOOL *allow);


void __RPC_STUB INetFwIcmpSettings_get_AllowInboundTimestampRequest_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][id] */ HRESULT STDMETHODCALLTYPE INetFwIcmpSettings_put_AllowInboundTimestampRequest_Proxy( 
    INetFwIcmpSettings * This,
    /* [in] */ VARIANT_BOOL allow);


void __RPC_STUB INetFwIcmpSettings_put_AllowInboundTimestampRequest_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwIcmpSettings_get_AllowInboundMaskRequest_Proxy( 
    INetFwIcmpSettings * This,
    /* [retval][out] */ VARIANT_BOOL *allow);


void __RPC_STUB INetFwIcmpSettings_get_AllowInboundMaskRequest_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][id] */ HRESULT STDMETHODCALLTYPE INetFwIcmpSettings_put_AllowInboundMaskRequest_Proxy( 
    INetFwIcmpSettings * This,
    /* [in] */ VARIANT_BOOL allow);


void __RPC_STUB INetFwIcmpSettings_put_AllowInboundMaskRequest_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwIcmpSettings_get_AllowOutboundPacketTooBig_Proxy( 
    INetFwIcmpSettings * This,
    /* [retval][out] */ VARIANT_BOOL *allow);


void __RPC_STUB INetFwIcmpSettings_get_AllowOutboundPacketTooBig_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][id] */ HRESULT STDMETHODCALLTYPE INetFwIcmpSettings_put_AllowOutboundPacketTooBig_Proxy( 
    INetFwIcmpSettings * This,
    /* [in] */ VARIANT_BOOL allow);


void __RPC_STUB INetFwIcmpSettings_put_AllowOutboundPacketTooBig_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __INetFwIcmpSettings_INTERFACE_DEFINED__ */


#ifndef __INetFwOpenPort_INTERFACE_DEFINED__
#define __INetFwOpenPort_INTERFACE_DEFINED__

/* interface INetFwOpenPort */
/* [dual][uuid][object] */ 


EXTERN_C const IID IID_INetFwOpenPort;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("E0483BA0-47FF-4D9C-A6D6-7741D0B195F7")
    INetFwOpenPort : public IDispatch
    {
    public:
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_Name( 
            /* [retval][out] */ BSTR *name) = 0;
        
        virtual /* [propput][id] */ HRESULT STDMETHODCALLTYPE put_Name( 
            /* [in] */ BSTR name) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_IpVersion( 
            /* [retval][out] */ NET_FW_IP_VERSION *ipVersion) = 0;
        
        virtual /* [propput][id] */ HRESULT STDMETHODCALLTYPE put_IpVersion( 
            /* [in] */ NET_FW_IP_VERSION ipVersion) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_Protocol( 
            /* [retval][out] */ NET_FW_IP_PROTOCOL *ipProtocol) = 0;
        
        virtual /* [propput][id] */ HRESULT STDMETHODCALLTYPE put_Protocol( 
            /* [in] */ NET_FW_IP_PROTOCOL ipProtocol) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_Port( 
            /* [retval][out] */ LONG *portNumber) = 0;
        
        virtual /* [propput][id] */ HRESULT STDMETHODCALLTYPE put_Port( 
            /* [in] */ LONG portNumber) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_Scope( 
            /* [retval][out] */ NET_FW_SCOPE *scope) = 0;
        
        virtual /* [propput][id] */ HRESULT STDMETHODCALLTYPE put_Scope( 
            /* [in] */ NET_FW_SCOPE scope) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_RemoteAddresses( 
            /* [retval][out] */ BSTR *remoteAddrs) = 0;
        
        virtual /* [propput][id] */ HRESULT STDMETHODCALLTYPE put_RemoteAddresses( 
            /* [in] */ BSTR remoteAddrs) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_Enabled( 
            /* [retval][out] */ VARIANT_BOOL *enabled) = 0;
        
        virtual /* [propput][id] */ HRESULT STDMETHODCALLTYPE put_Enabled( 
            /* [in] */ VARIANT_BOOL enabled) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_BuiltIn( 
            /* [retval][out] */ VARIANT_BOOL *builtIn) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct INetFwOpenPortVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE *QueryInterface )( 
            INetFwOpenPort * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void **ppvObject);
        
        ULONG ( STDMETHODCALLTYPE *AddRef )( 
            INetFwOpenPort * This);
        
        ULONG ( STDMETHODCALLTYPE *Release )( 
            INetFwOpenPort * This);
        
        HRESULT ( STDMETHODCALLTYPE *GetTypeInfoCount )( 
            INetFwOpenPort * This,
            /* [out] */ UINT *pctinfo);
        
        HRESULT ( STDMETHODCALLTYPE *GetTypeInfo )( 
            INetFwOpenPort * This,
            /* [in] */ UINT iTInfo,
            /* [in] */ LCID lcid,
            /* [out] */ ITypeInfo **ppTInfo);
        
        HRESULT ( STDMETHODCALLTYPE *GetIDsOfNames )( 
            INetFwOpenPort * This,
            /* [in] */ REFIID riid,
            /* [size_is][in] */ LPOLESTR *rgszNames,
            /* [in] */ UINT cNames,
            /* [in] */ LCID lcid,
            /* [size_is][out] */ DISPID *rgDispId);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE *Invoke )( 
            INetFwOpenPort * This,
            /* [in] */ DISPID dispIdMember,
            /* [in] */ REFIID riid,
            /* [in] */ LCID lcid,
            /* [in] */ WORD wFlags,
            /* [out][in] */ DISPPARAMS *pDispParams,
            /* [out] */ VARIANT *pVarResult,
            /* [out] */ EXCEPINFO *pExcepInfo,
            /* [out] */ UINT *puArgErr);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_Name )( 
            INetFwOpenPort * This,
            /* [retval][out] */ BSTR *name);
        
        /* [propput][id] */ HRESULT ( STDMETHODCALLTYPE *put_Name )( 
            INetFwOpenPort * This,
            /* [in] */ BSTR name);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_IpVersion )( 
            INetFwOpenPort * This,
            /* [retval][out] */ NET_FW_IP_VERSION *ipVersion);
        
        /* [propput][id] */ HRESULT ( STDMETHODCALLTYPE *put_IpVersion )( 
            INetFwOpenPort * This,
            /* [in] */ NET_FW_IP_VERSION ipVersion);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_Protocol )( 
            INetFwOpenPort * This,
            /* [retval][out] */ NET_FW_IP_PROTOCOL *ipProtocol);
        
        /* [propput][id] */ HRESULT ( STDMETHODCALLTYPE *put_Protocol )( 
            INetFwOpenPort * This,
            /* [in] */ NET_FW_IP_PROTOCOL ipProtocol);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_Port )( 
            INetFwOpenPort * This,
            /* [retval][out] */ LONG *portNumber);
        
        /* [propput][id] */ HRESULT ( STDMETHODCALLTYPE *put_Port )( 
            INetFwOpenPort * This,
            /* [in] */ LONG portNumber);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_Scope )( 
            INetFwOpenPort * This,
            /* [retval][out] */ NET_FW_SCOPE *scope);
        
        /* [propput][id] */ HRESULT ( STDMETHODCALLTYPE *put_Scope )( 
            INetFwOpenPort * This,
            /* [in] */ NET_FW_SCOPE scope);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_RemoteAddresses )( 
            INetFwOpenPort * This,
            /* [retval][out] */ BSTR *remoteAddrs);
        
        /* [propput][id] */ HRESULT ( STDMETHODCALLTYPE *put_RemoteAddresses )( 
            INetFwOpenPort * This,
            /* [in] */ BSTR remoteAddrs);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_Enabled )( 
            INetFwOpenPort * This,
            /* [retval][out] */ VARIANT_BOOL *enabled);
        
        /* [propput][id] */ HRESULT ( STDMETHODCALLTYPE *put_Enabled )( 
            INetFwOpenPort * This,
            /* [in] */ VARIANT_BOOL enabled);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_BuiltIn )( 
            INetFwOpenPort * This,
            /* [retval][out] */ VARIANT_BOOL *builtIn);
        
        END_INTERFACE
    } INetFwOpenPortVtbl;

    interface INetFwOpenPort
    {
        CONST_VTBL struct INetFwOpenPortVtbl *lpVtbl;
    };

    

#ifdef COBJMACROS


#define INetFwOpenPort_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define INetFwOpenPort_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define INetFwOpenPort_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define INetFwOpenPort_GetTypeInfoCount(This,pctinfo)	\
    (This)->lpVtbl -> GetTypeInfoCount(This,pctinfo)

#define INetFwOpenPort_GetTypeInfo(This,iTInfo,lcid,ppTInfo)	\
    (This)->lpVtbl -> GetTypeInfo(This,iTInfo,lcid,ppTInfo)

#define INetFwOpenPort_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)	\
    (This)->lpVtbl -> GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)

#define INetFwOpenPort_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)	\
    (This)->lpVtbl -> Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)


#define INetFwOpenPort_get_Name(This,name)	\
    (This)->lpVtbl -> get_Name(This,name)

#define INetFwOpenPort_put_Name(This,name)	\
    (This)->lpVtbl -> put_Name(This,name)

#define INetFwOpenPort_get_IpVersion(This,ipVersion)	\
    (This)->lpVtbl -> get_IpVersion(This,ipVersion)

#define INetFwOpenPort_put_IpVersion(This,ipVersion)	\
    (This)->lpVtbl -> put_IpVersion(This,ipVersion)

#define INetFwOpenPort_get_Protocol(This,ipProtocol)	\
    (This)->lpVtbl -> get_Protocol(This,ipProtocol)

#define INetFwOpenPort_put_Protocol(This,ipProtocol)	\
    (This)->lpVtbl -> put_Protocol(This,ipProtocol)

#define INetFwOpenPort_get_Port(This,portNumber)	\
    (This)->lpVtbl -> get_Port(This,portNumber)

#define INetFwOpenPort_put_Port(This,portNumber)	\
    (This)->lpVtbl -> put_Port(This,portNumber)

#define INetFwOpenPort_get_Scope(This,scope)	\
    (This)->lpVtbl -> get_Scope(This,scope)

#define INetFwOpenPort_put_Scope(This,scope)	\
    (This)->lpVtbl -> put_Scope(This,scope)

#define INetFwOpenPort_get_RemoteAddresses(This,remoteAddrs)	\
    (This)->lpVtbl -> get_RemoteAddresses(This,remoteAddrs)

#define INetFwOpenPort_put_RemoteAddresses(This,remoteAddrs)	\
    (This)->lpVtbl -> put_RemoteAddresses(This,remoteAddrs)

#define INetFwOpenPort_get_Enabled(This,enabled)	\
    (This)->lpVtbl -> get_Enabled(This,enabled)

#define INetFwOpenPort_put_Enabled(This,enabled)	\
    (This)->lpVtbl -> put_Enabled(This,enabled)

#define INetFwOpenPort_get_BuiltIn(This,builtIn)	\
    (This)->lpVtbl -> get_BuiltIn(This,builtIn)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwOpenPort_get_Name_Proxy( 
    INetFwOpenPort * This,
    /* [retval][out] */ BSTR *name);


void __RPC_STUB INetFwOpenPort_get_Name_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][id] */ HRESULT STDMETHODCALLTYPE INetFwOpenPort_put_Name_Proxy( 
    INetFwOpenPort * This,
    /* [in] */ BSTR name);


void __RPC_STUB INetFwOpenPort_put_Name_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwOpenPort_get_IpVersion_Proxy( 
    INetFwOpenPort * This,
    /* [retval][out] */ NET_FW_IP_VERSION *ipVersion);


void __RPC_STUB INetFwOpenPort_get_IpVersion_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][id] */ HRESULT STDMETHODCALLTYPE INetFwOpenPort_put_IpVersion_Proxy( 
    INetFwOpenPort * This,
    /* [in] */ NET_FW_IP_VERSION ipVersion);


void __RPC_STUB INetFwOpenPort_put_IpVersion_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwOpenPort_get_Protocol_Proxy( 
    INetFwOpenPort * This,
    /* [retval][out] */ NET_FW_IP_PROTOCOL *ipProtocol);


void __RPC_STUB INetFwOpenPort_get_Protocol_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][id] */ HRESULT STDMETHODCALLTYPE INetFwOpenPort_put_Protocol_Proxy( 
    INetFwOpenPort * This,
    /* [in] */ NET_FW_IP_PROTOCOL ipProtocol);


void __RPC_STUB INetFwOpenPort_put_Protocol_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwOpenPort_get_Port_Proxy( 
    INetFwOpenPort * This,
    /* [retval][out] */ LONG *portNumber);


void __RPC_STUB INetFwOpenPort_get_Port_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][id] */ HRESULT STDMETHODCALLTYPE INetFwOpenPort_put_Port_Proxy( 
    INetFwOpenPort * This,
    /* [in] */ LONG portNumber);


void __RPC_STUB INetFwOpenPort_put_Port_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwOpenPort_get_Scope_Proxy( 
    INetFwOpenPort * This,
    /* [retval][out] */ NET_FW_SCOPE *scope);


void __RPC_STUB INetFwOpenPort_get_Scope_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][id] */ HRESULT STDMETHODCALLTYPE INetFwOpenPort_put_Scope_Proxy( 
    INetFwOpenPort * This,
    /* [in] */ NET_FW_SCOPE scope);


void __RPC_STUB INetFwOpenPort_put_Scope_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwOpenPort_get_RemoteAddresses_Proxy( 
    INetFwOpenPort * This,
    /* [retval][out] */ BSTR *remoteAddrs);


void __RPC_STUB INetFwOpenPort_get_RemoteAddresses_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][id] */ HRESULT STDMETHODCALLTYPE INetFwOpenPort_put_RemoteAddresses_Proxy( 
    INetFwOpenPort * This,
    /* [in] */ BSTR remoteAddrs);


void __RPC_STUB INetFwOpenPort_put_RemoteAddresses_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwOpenPort_get_Enabled_Proxy( 
    INetFwOpenPort * This,
    /* [retval][out] */ VARIANT_BOOL *enabled);


void __RPC_STUB INetFwOpenPort_get_Enabled_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][id] */ HRESULT STDMETHODCALLTYPE INetFwOpenPort_put_Enabled_Proxy( 
    INetFwOpenPort * This,
    /* [in] */ VARIANT_BOOL enabled);


void __RPC_STUB INetFwOpenPort_put_Enabled_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwOpenPort_get_BuiltIn_Proxy( 
    INetFwOpenPort * This,
    /* [retval][out] */ VARIANT_BOOL *builtIn);


void __RPC_STUB INetFwOpenPort_get_BuiltIn_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __INetFwOpenPort_INTERFACE_DEFINED__ */


#ifndef __INetFwOpenPorts_INTERFACE_DEFINED__
#define __INetFwOpenPorts_INTERFACE_DEFINED__

/* interface INetFwOpenPorts */
/* [dual][uuid][object] */ 


EXTERN_C const IID IID_INetFwOpenPorts;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("C0E9D7FA-E07E-430A-B19A-090CE82D92E2")
    INetFwOpenPorts : public IDispatch
    {
    public:
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_Count( 
            /* [retval][out] */ long *count) = 0;
        
        virtual /* [id] */ HRESULT STDMETHODCALLTYPE Add( 
            /* [in] */ INetFwOpenPort *port) = 0;
        
        virtual /* [id] */ HRESULT STDMETHODCALLTYPE Remove( 
            /* [in] */ LONG portNumber,
            /* [in] */ NET_FW_IP_PROTOCOL ipProtocol) = 0;
        
        virtual /* [id] */ HRESULT STDMETHODCALLTYPE Item( 
            /* [in] */ LONG portNumber,
            /* [in] */ NET_FW_IP_PROTOCOL ipProtocol,
            /* [retval][out] */ INetFwOpenPort **openPort) = 0;
        
        virtual /* [restricted][propget][id] */ HRESULT STDMETHODCALLTYPE get__NewEnum( 
            /* [retval][out] */ IUnknown **newEnum) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct INetFwOpenPortsVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE *QueryInterface )( 
            INetFwOpenPorts * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void **ppvObject);
        
        ULONG ( STDMETHODCALLTYPE *AddRef )( 
            INetFwOpenPorts * This);
        
        ULONG ( STDMETHODCALLTYPE *Release )( 
            INetFwOpenPorts * This);
        
        HRESULT ( STDMETHODCALLTYPE *GetTypeInfoCount )( 
            INetFwOpenPorts * This,
            /* [out] */ UINT *pctinfo);
        
        HRESULT ( STDMETHODCALLTYPE *GetTypeInfo )( 
            INetFwOpenPorts * This,
            /* [in] */ UINT iTInfo,
            /* [in] */ LCID lcid,
            /* [out] */ ITypeInfo **ppTInfo);
        
        HRESULT ( STDMETHODCALLTYPE *GetIDsOfNames )( 
            INetFwOpenPorts * This,
            /* [in] */ REFIID riid,
            /* [size_is][in] */ LPOLESTR *rgszNames,
            /* [in] */ UINT cNames,
            /* [in] */ LCID lcid,
            /* [size_is][out] */ DISPID *rgDispId);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE *Invoke )( 
            INetFwOpenPorts * This,
            /* [in] */ DISPID dispIdMember,
            /* [in] */ REFIID riid,
            /* [in] */ LCID lcid,
            /* [in] */ WORD wFlags,
            /* [out][in] */ DISPPARAMS *pDispParams,
            /* [out] */ VARIANT *pVarResult,
            /* [out] */ EXCEPINFO *pExcepInfo,
            /* [out] */ UINT *puArgErr);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_Count )( 
            INetFwOpenPorts * This,
            /* [retval][out] */ long *count);
        
        /* [id] */ HRESULT ( STDMETHODCALLTYPE *Add )( 
            INetFwOpenPorts * This,
            /* [in] */ INetFwOpenPort *port);
        
        /* [id] */ HRESULT ( STDMETHODCALLTYPE *Remove )( 
            INetFwOpenPorts * This,
            /* [in] */ LONG portNumber,
            /* [in] */ NET_FW_IP_PROTOCOL ipProtocol);
        
        /* [id] */ HRESULT ( STDMETHODCALLTYPE *Item )( 
            INetFwOpenPorts * This,
            /* [in] */ LONG portNumber,
            /* [in] */ NET_FW_IP_PROTOCOL ipProtocol,
            /* [retval][out] */ INetFwOpenPort **openPort);
        
        /* [restricted][propget][id] */ HRESULT ( STDMETHODCALLTYPE *get__NewEnum )( 
            INetFwOpenPorts * This,
            /* [retval][out] */ IUnknown **newEnum);
        
        END_INTERFACE
    } INetFwOpenPortsVtbl;

    interface INetFwOpenPorts
    {
        CONST_VTBL struct INetFwOpenPortsVtbl *lpVtbl;
    };

    

#ifdef COBJMACROS


#define INetFwOpenPorts_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define INetFwOpenPorts_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define INetFwOpenPorts_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define INetFwOpenPorts_GetTypeInfoCount(This,pctinfo)	\
    (This)->lpVtbl -> GetTypeInfoCount(This,pctinfo)

#define INetFwOpenPorts_GetTypeInfo(This,iTInfo,lcid,ppTInfo)	\
    (This)->lpVtbl -> GetTypeInfo(This,iTInfo,lcid,ppTInfo)

#define INetFwOpenPorts_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)	\
    (This)->lpVtbl -> GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)

#define INetFwOpenPorts_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)	\
    (This)->lpVtbl -> Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)


#define INetFwOpenPorts_get_Count(This,count)	\
    (This)->lpVtbl -> get_Count(This,count)

#define INetFwOpenPorts_Add(This,port)	\
    (This)->lpVtbl -> Add(This,port)

#define INetFwOpenPorts_Remove(This,portNumber,ipProtocol)	\
    (This)->lpVtbl -> Remove(This,portNumber,ipProtocol)

#define INetFwOpenPorts_Item(This,portNumber,ipProtocol,openPort)	\
    (This)->lpVtbl -> Item(This,portNumber,ipProtocol,openPort)

#define INetFwOpenPorts_get__NewEnum(This,newEnum)	\
    (This)->lpVtbl -> get__NewEnum(This,newEnum)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwOpenPorts_get_Count_Proxy( 
    INetFwOpenPorts * This,
    /* [retval][out] */ long *count);


void __RPC_STUB INetFwOpenPorts_get_Count_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [id] */ HRESULT STDMETHODCALLTYPE INetFwOpenPorts_Add_Proxy( 
    INetFwOpenPorts * This,
    /* [in] */ INetFwOpenPort *port);


void __RPC_STUB INetFwOpenPorts_Add_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [id] */ HRESULT STDMETHODCALLTYPE INetFwOpenPorts_Remove_Proxy( 
    INetFwOpenPorts * This,
    /* [in] */ LONG portNumber,
    /* [in] */ NET_FW_IP_PROTOCOL ipProtocol);


void __RPC_STUB INetFwOpenPorts_Remove_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [id] */ HRESULT STDMETHODCALLTYPE INetFwOpenPorts_Item_Proxy( 
    INetFwOpenPorts * This,
    /* [in] */ LONG portNumber,
    /* [in] */ NET_FW_IP_PROTOCOL ipProtocol,
    /* [retval][out] */ INetFwOpenPort **openPort);


void __RPC_STUB INetFwOpenPorts_Item_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [restricted][propget][id] */ HRESULT STDMETHODCALLTYPE INetFwOpenPorts_get__NewEnum_Proxy( 
    INetFwOpenPorts * This,
    /* [retval][out] */ IUnknown **newEnum);


void __RPC_STUB INetFwOpenPorts_get__NewEnum_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __INetFwOpenPorts_INTERFACE_DEFINED__ */


#ifndef __INetFwService_INTERFACE_DEFINED__
#define __INetFwService_INTERFACE_DEFINED__

/* interface INetFwService */
/* [dual][uuid][object] */ 


EXTERN_C const IID IID_INetFwService;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("79FD57C8-908E-4A36-9888-D5B3F0A444CF")
    INetFwService : public IDispatch
    {
    public:
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_Name( 
            /* [retval][out] */ BSTR *name) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_Type( 
            /* [retval][out] */ NET_FW_SERVICE_TYPE *type) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_Customized( 
            /* [retval][out] */ VARIANT_BOOL *customized) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_IpVersion( 
            /* [retval][out] */ NET_FW_IP_VERSION *ipVersion) = 0;
        
        virtual /* [propput][id] */ HRESULT STDMETHODCALLTYPE put_IpVersion( 
            /* [in] */ NET_FW_IP_VERSION ipVersion) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_Scope( 
            /* [retval][out] */ NET_FW_SCOPE *scope) = 0;
        
        virtual /* [propput][id] */ HRESULT STDMETHODCALLTYPE put_Scope( 
            /* [in] */ NET_FW_SCOPE scope) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_RemoteAddresses( 
            /* [retval][out] */ BSTR *remoteAddrs) = 0;
        
        virtual /* [propput][id] */ HRESULT STDMETHODCALLTYPE put_RemoteAddresses( 
            /* [in] */ BSTR remoteAddrs) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_Enabled( 
            /* [retval][out] */ VARIANT_BOOL *enabled) = 0;
        
        virtual /* [propput][id] */ HRESULT STDMETHODCALLTYPE put_Enabled( 
            /* [in] */ VARIANT_BOOL enabled) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_GloballyOpenPorts( 
            /* [retval][out] */ INetFwOpenPorts **openPorts) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct INetFwServiceVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE *QueryInterface )( 
            INetFwService * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void **ppvObject);
        
        ULONG ( STDMETHODCALLTYPE *AddRef )( 
            INetFwService * This);
        
        ULONG ( STDMETHODCALLTYPE *Release )( 
            INetFwService * This);
        
        HRESULT ( STDMETHODCALLTYPE *GetTypeInfoCount )( 
            INetFwService * This,
            /* [out] */ UINT *pctinfo);
        
        HRESULT ( STDMETHODCALLTYPE *GetTypeInfo )( 
            INetFwService * This,
            /* [in] */ UINT iTInfo,
            /* [in] */ LCID lcid,
            /* [out] */ ITypeInfo **ppTInfo);
        
        HRESULT ( STDMETHODCALLTYPE *GetIDsOfNames )( 
            INetFwService * This,
            /* [in] */ REFIID riid,
            /* [size_is][in] */ LPOLESTR *rgszNames,
            /* [in] */ UINT cNames,
            /* [in] */ LCID lcid,
            /* [size_is][out] */ DISPID *rgDispId);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE *Invoke )( 
            INetFwService * This,
            /* [in] */ DISPID dispIdMember,
            /* [in] */ REFIID riid,
            /* [in] */ LCID lcid,
            /* [in] */ WORD wFlags,
            /* [out][in] */ DISPPARAMS *pDispParams,
            /* [out] */ VARIANT *pVarResult,
            /* [out] */ EXCEPINFO *pExcepInfo,
            /* [out] */ UINT *puArgErr);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_Name )( 
            INetFwService * This,
            /* [retval][out] */ BSTR *name);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_Type )( 
            INetFwService * This,
            /* [retval][out] */ NET_FW_SERVICE_TYPE *type);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_Customized )( 
            INetFwService * This,
            /* [retval][out] */ VARIANT_BOOL *customized);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_IpVersion )( 
            INetFwService * This,
            /* [retval][out] */ NET_FW_IP_VERSION *ipVersion);
        
        /* [propput][id] */ HRESULT ( STDMETHODCALLTYPE *put_IpVersion )( 
            INetFwService * This,
            /* [in] */ NET_FW_IP_VERSION ipVersion);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_Scope )( 
            INetFwService * This,
            /* [retval][out] */ NET_FW_SCOPE *scope);
        
        /* [propput][id] */ HRESULT ( STDMETHODCALLTYPE *put_Scope )( 
            INetFwService * This,
            /* [in] */ NET_FW_SCOPE scope);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_RemoteAddresses )( 
            INetFwService * This,
            /* [retval][out] */ BSTR *remoteAddrs);
        
        /* [propput][id] */ HRESULT ( STDMETHODCALLTYPE *put_RemoteAddresses )( 
            INetFwService * This,
            /* [in] */ BSTR remoteAddrs);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_Enabled )( 
            INetFwService * This,
            /* [retval][out] */ VARIANT_BOOL *enabled);
        
        /* [propput][id] */ HRESULT ( STDMETHODCALLTYPE *put_Enabled )( 
            INetFwService * This,
            /* [in] */ VARIANT_BOOL enabled);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_GloballyOpenPorts )( 
            INetFwService * This,
            /* [retval][out] */ INetFwOpenPorts **openPorts);
        
        END_INTERFACE
    } INetFwServiceVtbl;

    interface INetFwService
    {
        CONST_VTBL struct INetFwServiceVtbl *lpVtbl;
    };

    

#ifdef COBJMACROS


#define INetFwService_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define INetFwService_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define INetFwService_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define INetFwService_GetTypeInfoCount(This,pctinfo)	\
    (This)->lpVtbl -> GetTypeInfoCount(This,pctinfo)

#define INetFwService_GetTypeInfo(This,iTInfo,lcid,ppTInfo)	\
    (This)->lpVtbl -> GetTypeInfo(This,iTInfo,lcid,ppTInfo)

#define INetFwService_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)	\
    (This)->lpVtbl -> GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)

#define INetFwService_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)	\
    (This)->lpVtbl -> Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)


#define INetFwService_get_Name(This,name)	\
    (This)->lpVtbl -> get_Name(This,name)

#define INetFwService_get_Type(This,type)	\
    (This)->lpVtbl -> get_Type(This,type)

#define INetFwService_get_Customized(This,customized)	\
    (This)->lpVtbl -> get_Customized(This,customized)

#define INetFwService_get_IpVersion(This,ipVersion)	\
    (This)->lpVtbl -> get_IpVersion(This,ipVersion)

#define INetFwService_put_IpVersion(This,ipVersion)	\
    (This)->lpVtbl -> put_IpVersion(This,ipVersion)

#define INetFwService_get_Scope(This,scope)	\
    (This)->lpVtbl -> get_Scope(This,scope)

#define INetFwService_put_Scope(This,scope)	\
    (This)->lpVtbl -> put_Scope(This,scope)

#define INetFwService_get_RemoteAddresses(This,remoteAddrs)	\
    (This)->lpVtbl -> get_RemoteAddresses(This,remoteAddrs)

#define INetFwService_put_RemoteAddresses(This,remoteAddrs)	\
    (This)->lpVtbl -> put_RemoteAddresses(This,remoteAddrs)

#define INetFwService_get_Enabled(This,enabled)	\
    (This)->lpVtbl -> get_Enabled(This,enabled)

#define INetFwService_put_Enabled(This,enabled)	\
    (This)->lpVtbl -> put_Enabled(This,enabled)

#define INetFwService_get_GloballyOpenPorts(This,openPorts)	\
    (This)->lpVtbl -> get_GloballyOpenPorts(This,openPorts)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwService_get_Name_Proxy( 
    INetFwService * This,
    /* [retval][out] */ BSTR *name);


void __RPC_STUB INetFwService_get_Name_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwService_get_Type_Proxy( 
    INetFwService * This,
    /* [retval][out] */ NET_FW_SERVICE_TYPE *type);


void __RPC_STUB INetFwService_get_Type_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwService_get_Customized_Proxy( 
    INetFwService * This,
    /* [retval][out] */ VARIANT_BOOL *customized);


void __RPC_STUB INetFwService_get_Customized_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwService_get_IpVersion_Proxy( 
    INetFwService * This,
    /* [retval][out] */ NET_FW_IP_VERSION *ipVersion);


void __RPC_STUB INetFwService_get_IpVersion_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][id] */ HRESULT STDMETHODCALLTYPE INetFwService_put_IpVersion_Proxy( 
    INetFwService * This,
    /* [in] */ NET_FW_IP_VERSION ipVersion);


void __RPC_STUB INetFwService_put_IpVersion_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwService_get_Scope_Proxy( 
    INetFwService * This,
    /* [retval][out] */ NET_FW_SCOPE *scope);


void __RPC_STUB INetFwService_get_Scope_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][id] */ HRESULT STDMETHODCALLTYPE INetFwService_put_Scope_Proxy( 
    INetFwService * This,
    /* [in] */ NET_FW_SCOPE scope);


void __RPC_STUB INetFwService_put_Scope_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwService_get_RemoteAddresses_Proxy( 
    INetFwService * This,
    /* [retval][out] */ BSTR *remoteAddrs);


void __RPC_STUB INetFwService_get_RemoteAddresses_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][id] */ HRESULT STDMETHODCALLTYPE INetFwService_put_RemoteAddresses_Proxy( 
    INetFwService * This,
    /* [in] */ BSTR remoteAddrs);


void __RPC_STUB INetFwService_put_RemoteAddresses_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwService_get_Enabled_Proxy( 
    INetFwService * This,
    /* [retval][out] */ VARIANT_BOOL *enabled);


void __RPC_STUB INetFwService_get_Enabled_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][id] */ HRESULT STDMETHODCALLTYPE INetFwService_put_Enabled_Proxy( 
    INetFwService * This,
    /* [in] */ VARIANT_BOOL enabled);


void __RPC_STUB INetFwService_put_Enabled_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwService_get_GloballyOpenPorts_Proxy( 
    INetFwService * This,
    /* [retval][out] */ INetFwOpenPorts **openPorts);


void __RPC_STUB INetFwService_get_GloballyOpenPorts_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __INetFwService_INTERFACE_DEFINED__ */


#ifndef __INetFwServices_INTERFACE_DEFINED__
#define __INetFwServices_INTERFACE_DEFINED__

/* interface INetFwServices */
/* [dual][uuid][object] */ 


EXTERN_C const IID IID_INetFwServices;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("79649BB4-903E-421B-94C9-79848E79F6EE")
    INetFwServices : public IDispatch
    {
    public:
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_Count( 
            /* [retval][out] */ long *count) = 0;
        
        virtual /* [id] */ HRESULT STDMETHODCALLTYPE Item( 
            /* [in] */ NET_FW_SERVICE_TYPE svcType,
            /* [retval][out] */ INetFwService **service) = 0;
        
        virtual /* [restricted][propget][id] */ HRESULT STDMETHODCALLTYPE get__NewEnum( 
            /* [retval][out] */ IUnknown **newEnum) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct INetFwServicesVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE *QueryInterface )( 
            INetFwServices * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void **ppvObject);
        
        ULONG ( STDMETHODCALLTYPE *AddRef )( 
            INetFwServices * This);
        
        ULONG ( STDMETHODCALLTYPE *Release )( 
            INetFwServices * This);
        
        HRESULT ( STDMETHODCALLTYPE *GetTypeInfoCount )( 
            INetFwServices * This,
            /* [out] */ UINT *pctinfo);
        
        HRESULT ( STDMETHODCALLTYPE *GetTypeInfo )( 
            INetFwServices * This,
            /* [in] */ UINT iTInfo,
            /* [in] */ LCID lcid,
            /* [out] */ ITypeInfo **ppTInfo);
        
        HRESULT ( STDMETHODCALLTYPE *GetIDsOfNames )( 
            INetFwServices * This,
            /* [in] */ REFIID riid,
            /* [size_is][in] */ LPOLESTR *rgszNames,
            /* [in] */ UINT cNames,
            /* [in] */ LCID lcid,
            /* [size_is][out] */ DISPID *rgDispId);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE *Invoke )( 
            INetFwServices * This,
            /* [in] */ DISPID dispIdMember,
            /* [in] */ REFIID riid,
            /* [in] */ LCID lcid,
            /* [in] */ WORD wFlags,
            /* [out][in] */ DISPPARAMS *pDispParams,
            /* [out] */ VARIANT *pVarResult,
            /* [out] */ EXCEPINFO *pExcepInfo,
            /* [out] */ UINT *puArgErr);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_Count )( 
            INetFwServices * This,
            /* [retval][out] */ long *count);
        
        /* [id] */ HRESULT ( STDMETHODCALLTYPE *Item )( 
            INetFwServices * This,
            /* [in] */ NET_FW_SERVICE_TYPE svcType,
            /* [retval][out] */ INetFwService **service);
        
        /* [restricted][propget][id] */ HRESULT ( STDMETHODCALLTYPE *get__NewEnum )( 
            INetFwServices * This,
            /* [retval][out] */ IUnknown **newEnum);
        
        END_INTERFACE
    } INetFwServicesVtbl;

    interface INetFwServices
    {
        CONST_VTBL struct INetFwServicesVtbl *lpVtbl;
    };

    

#ifdef COBJMACROS


#define INetFwServices_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define INetFwServices_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define INetFwServices_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define INetFwServices_GetTypeInfoCount(This,pctinfo)	\
    (This)->lpVtbl -> GetTypeInfoCount(This,pctinfo)

#define INetFwServices_GetTypeInfo(This,iTInfo,lcid,ppTInfo)	\
    (This)->lpVtbl -> GetTypeInfo(This,iTInfo,lcid,ppTInfo)

#define INetFwServices_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)	\
    (This)->lpVtbl -> GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)

#define INetFwServices_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)	\
    (This)->lpVtbl -> Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)


#define INetFwServices_get_Count(This,count)	\
    (This)->lpVtbl -> get_Count(This,count)

#define INetFwServices_Item(This,svcType,service)	\
    (This)->lpVtbl -> Item(This,svcType,service)

#define INetFwServices_get__NewEnum(This,newEnum)	\
    (This)->lpVtbl -> get__NewEnum(This,newEnum)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwServices_get_Count_Proxy( 
    INetFwServices * This,
    /* [retval][out] */ long *count);


void __RPC_STUB INetFwServices_get_Count_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [id] */ HRESULT STDMETHODCALLTYPE INetFwServices_Item_Proxy( 
    INetFwServices * This,
    /* [in] */ NET_FW_SERVICE_TYPE svcType,
    /* [retval][out] */ INetFwService **service);


void __RPC_STUB INetFwServices_Item_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [restricted][propget][id] */ HRESULT STDMETHODCALLTYPE INetFwServices_get__NewEnum_Proxy( 
    INetFwServices * This,
    /* [retval][out] */ IUnknown **newEnum);


void __RPC_STUB INetFwServices_get__NewEnum_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __INetFwServices_INTERFACE_DEFINED__ */


#ifndef __INetFwAuthorizedApplication_INTERFACE_DEFINED__
#define __INetFwAuthorizedApplication_INTERFACE_DEFINED__

/* interface INetFwAuthorizedApplication */
/* [dual][uuid][object] */ 


EXTERN_C const IID IID_INetFwAuthorizedApplication;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("B5E64FFA-C2C5-444E-A301-FB5E00018050")
    INetFwAuthorizedApplication : public IDispatch
    {
    public:
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_Name( 
            /* [retval][out] */ BSTR *name) = 0;
        
        virtual /* [propput][id] */ HRESULT STDMETHODCALLTYPE put_Name( 
            /* [in] */ BSTR name) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_ProcessImageFileName( 
            /* [retval][out] */ BSTR *imageFileName) = 0;
        
        virtual /* [propput][id] */ HRESULT STDMETHODCALLTYPE put_ProcessImageFileName( 
            /* [in] */ BSTR imageFileName) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_IpVersion( 
            /* [retval][out] */ NET_FW_IP_VERSION *ipVersion) = 0;
        
        virtual /* [propput][id] */ HRESULT STDMETHODCALLTYPE put_IpVersion( 
            /* [in] */ NET_FW_IP_VERSION ipVersion) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_Scope( 
            /* [retval][out] */ NET_FW_SCOPE *scope) = 0;
        
        virtual /* [propput][id] */ HRESULT STDMETHODCALLTYPE put_Scope( 
            /* [in] */ NET_FW_SCOPE scope) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_RemoteAddresses( 
            /* [retval][out] */ BSTR *remoteAddrs) = 0;
        
        virtual /* [propput][id] */ HRESULT STDMETHODCALLTYPE put_RemoteAddresses( 
            /* [in] */ BSTR remoteAddrs) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_Enabled( 
            /* [retval][out] */ VARIANT_BOOL *enabled) = 0;
        
        virtual /* [propput][id] */ HRESULT STDMETHODCALLTYPE put_Enabled( 
            /* [in] */ VARIANT_BOOL enabled) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct INetFwAuthorizedApplicationVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE *QueryInterface )( 
            INetFwAuthorizedApplication * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void **ppvObject);
        
        ULONG ( STDMETHODCALLTYPE *AddRef )( 
            INetFwAuthorizedApplication * This);
        
        ULONG ( STDMETHODCALLTYPE *Release )( 
            INetFwAuthorizedApplication * This);
        
        HRESULT ( STDMETHODCALLTYPE *GetTypeInfoCount )( 
            INetFwAuthorizedApplication * This,
            /* [out] */ UINT *pctinfo);
        
        HRESULT ( STDMETHODCALLTYPE *GetTypeInfo )( 
            INetFwAuthorizedApplication * This,
            /* [in] */ UINT iTInfo,
            /* [in] */ LCID lcid,
            /* [out] */ ITypeInfo **ppTInfo);
        
        HRESULT ( STDMETHODCALLTYPE *GetIDsOfNames )( 
            INetFwAuthorizedApplication * This,
            /* [in] */ REFIID riid,
            /* [size_is][in] */ LPOLESTR *rgszNames,
            /* [in] */ UINT cNames,
            /* [in] */ LCID lcid,
            /* [size_is][out] */ DISPID *rgDispId);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE *Invoke )( 
            INetFwAuthorizedApplication * This,
            /* [in] */ DISPID dispIdMember,
            /* [in] */ REFIID riid,
            /* [in] */ LCID lcid,
            /* [in] */ WORD wFlags,
            /* [out][in] */ DISPPARAMS *pDispParams,
            /* [out] */ VARIANT *pVarResult,
            /* [out] */ EXCEPINFO *pExcepInfo,
            /* [out] */ UINT *puArgErr);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_Name )( 
            INetFwAuthorizedApplication * This,
            /* [retval][out] */ BSTR *name);
        
        /* [propput][id] */ HRESULT ( STDMETHODCALLTYPE *put_Name )( 
            INetFwAuthorizedApplication * This,
            /* [in] */ BSTR name);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_ProcessImageFileName )( 
            INetFwAuthorizedApplication * This,
            /* [retval][out] */ BSTR *imageFileName);
        
        /* [propput][id] */ HRESULT ( STDMETHODCALLTYPE *put_ProcessImageFileName )( 
            INetFwAuthorizedApplication * This,
            /* [in] */ BSTR imageFileName);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_IpVersion )( 
            INetFwAuthorizedApplication * This,
            /* [retval][out] */ NET_FW_IP_VERSION *ipVersion);
        
        /* [propput][id] */ HRESULT ( STDMETHODCALLTYPE *put_IpVersion )( 
            INetFwAuthorizedApplication * This,
            /* [in] */ NET_FW_IP_VERSION ipVersion);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_Scope )( 
            INetFwAuthorizedApplication * This,
            /* [retval][out] */ NET_FW_SCOPE *scope);
        
        /* [propput][id] */ HRESULT ( STDMETHODCALLTYPE *put_Scope )( 
            INetFwAuthorizedApplication * This,
            /* [in] */ NET_FW_SCOPE scope);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_RemoteAddresses )( 
            INetFwAuthorizedApplication * This,
            /* [retval][out] */ BSTR *remoteAddrs);
        
        /* [propput][id] */ HRESULT ( STDMETHODCALLTYPE *put_RemoteAddresses )( 
            INetFwAuthorizedApplication * This,
            /* [in] */ BSTR remoteAddrs);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_Enabled )( 
            INetFwAuthorizedApplication * This,
            /* [retval][out] */ VARIANT_BOOL *enabled);
        
        /* [propput][id] */ HRESULT ( STDMETHODCALLTYPE *put_Enabled )( 
            INetFwAuthorizedApplication * This,
            /* [in] */ VARIANT_BOOL enabled);
        
        END_INTERFACE
    } INetFwAuthorizedApplicationVtbl;

    interface INetFwAuthorizedApplication
    {
        CONST_VTBL struct INetFwAuthorizedApplicationVtbl *lpVtbl;
    };

    

#ifdef COBJMACROS


#define INetFwAuthorizedApplication_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define INetFwAuthorizedApplication_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define INetFwAuthorizedApplication_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define INetFwAuthorizedApplication_GetTypeInfoCount(This,pctinfo)	\
    (This)->lpVtbl -> GetTypeInfoCount(This,pctinfo)

#define INetFwAuthorizedApplication_GetTypeInfo(This,iTInfo,lcid,ppTInfo)	\
    (This)->lpVtbl -> GetTypeInfo(This,iTInfo,lcid,ppTInfo)

#define INetFwAuthorizedApplication_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)	\
    (This)->lpVtbl -> GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)

#define INetFwAuthorizedApplication_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)	\
    (This)->lpVtbl -> Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)


#define INetFwAuthorizedApplication_get_Name(This,name)	\
    (This)->lpVtbl -> get_Name(This,name)

#define INetFwAuthorizedApplication_put_Name(This,name)	\
    (This)->lpVtbl -> put_Name(This,name)

#define INetFwAuthorizedApplication_get_ProcessImageFileName(This,imageFileName)	\
    (This)->lpVtbl -> get_ProcessImageFileName(This,imageFileName)

#define INetFwAuthorizedApplication_put_ProcessImageFileName(This,imageFileName)	\
    (This)->lpVtbl -> put_ProcessImageFileName(This,imageFileName)

#define INetFwAuthorizedApplication_get_IpVersion(This,ipVersion)	\
    (This)->lpVtbl -> get_IpVersion(This,ipVersion)

#define INetFwAuthorizedApplication_put_IpVersion(This,ipVersion)	\
    (This)->lpVtbl -> put_IpVersion(This,ipVersion)

#define INetFwAuthorizedApplication_get_Scope(This,scope)	\
    (This)->lpVtbl -> get_Scope(This,scope)

#define INetFwAuthorizedApplication_put_Scope(This,scope)	\
    (This)->lpVtbl -> put_Scope(This,scope)

#define INetFwAuthorizedApplication_get_RemoteAddresses(This,remoteAddrs)	\
    (This)->lpVtbl -> get_RemoteAddresses(This,remoteAddrs)

#define INetFwAuthorizedApplication_put_RemoteAddresses(This,remoteAddrs)	\
    (This)->lpVtbl -> put_RemoteAddresses(This,remoteAddrs)

#define INetFwAuthorizedApplication_get_Enabled(This,enabled)	\
    (This)->lpVtbl -> get_Enabled(This,enabled)

#define INetFwAuthorizedApplication_put_Enabled(This,enabled)	\
    (This)->lpVtbl -> put_Enabled(This,enabled)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwAuthorizedApplication_get_Name_Proxy( 
    INetFwAuthorizedApplication * This,
    /* [retval][out] */ BSTR *name);


void __RPC_STUB INetFwAuthorizedApplication_get_Name_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][id] */ HRESULT STDMETHODCALLTYPE INetFwAuthorizedApplication_put_Name_Proxy( 
    INetFwAuthorizedApplication * This,
    /* [in] */ BSTR name);


void __RPC_STUB INetFwAuthorizedApplication_put_Name_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwAuthorizedApplication_get_ProcessImageFileName_Proxy( 
    INetFwAuthorizedApplication * This,
    /* [retval][out] */ BSTR *imageFileName);


void __RPC_STUB INetFwAuthorizedApplication_get_ProcessImageFileName_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][id] */ HRESULT STDMETHODCALLTYPE INetFwAuthorizedApplication_put_ProcessImageFileName_Proxy( 
    INetFwAuthorizedApplication * This,
    /* [in] */ BSTR imageFileName);


void __RPC_STUB INetFwAuthorizedApplication_put_ProcessImageFileName_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwAuthorizedApplication_get_IpVersion_Proxy( 
    INetFwAuthorizedApplication * This,
    /* [retval][out] */ NET_FW_IP_VERSION *ipVersion);


void __RPC_STUB INetFwAuthorizedApplication_get_IpVersion_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][id] */ HRESULT STDMETHODCALLTYPE INetFwAuthorizedApplication_put_IpVersion_Proxy( 
    INetFwAuthorizedApplication * This,
    /* [in] */ NET_FW_IP_VERSION ipVersion);


void __RPC_STUB INetFwAuthorizedApplication_put_IpVersion_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwAuthorizedApplication_get_Scope_Proxy( 
    INetFwAuthorizedApplication * This,
    /* [retval][out] */ NET_FW_SCOPE *scope);


void __RPC_STUB INetFwAuthorizedApplication_get_Scope_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][id] */ HRESULT STDMETHODCALLTYPE INetFwAuthorizedApplication_put_Scope_Proxy( 
    INetFwAuthorizedApplication * This,
    /* [in] */ NET_FW_SCOPE scope);


void __RPC_STUB INetFwAuthorizedApplication_put_Scope_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwAuthorizedApplication_get_RemoteAddresses_Proxy( 
    INetFwAuthorizedApplication * This,
    /* [retval][out] */ BSTR *remoteAddrs);


void __RPC_STUB INetFwAuthorizedApplication_get_RemoteAddresses_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][id] */ HRESULT STDMETHODCALLTYPE INetFwAuthorizedApplication_put_RemoteAddresses_Proxy( 
    INetFwAuthorizedApplication * This,
    /* [in] */ BSTR remoteAddrs);


void __RPC_STUB INetFwAuthorizedApplication_put_RemoteAddresses_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwAuthorizedApplication_get_Enabled_Proxy( 
    INetFwAuthorizedApplication * This,
    /* [retval][out] */ VARIANT_BOOL *enabled);


void __RPC_STUB INetFwAuthorizedApplication_get_Enabled_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][id] */ HRESULT STDMETHODCALLTYPE INetFwAuthorizedApplication_put_Enabled_Proxy( 
    INetFwAuthorizedApplication * This,
    /* [in] */ VARIANT_BOOL enabled);


void __RPC_STUB INetFwAuthorizedApplication_put_Enabled_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __INetFwAuthorizedApplication_INTERFACE_DEFINED__ */


#ifndef __INetFwAuthorizedApplications_INTERFACE_DEFINED__
#define __INetFwAuthorizedApplications_INTERFACE_DEFINED__

/* interface INetFwAuthorizedApplications */
/* [dual][uuid][object] */ 


EXTERN_C const IID IID_INetFwAuthorizedApplications;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("644EFD52-CCF9-486C-97A2-39F352570B30")
    INetFwAuthorizedApplications : public IDispatch
    {
    public:
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_Count( 
            /* [retval][out] */ long *count) = 0;
        
        virtual /* [id] */ HRESULT STDMETHODCALLTYPE Add( 
            /* [in] */ INetFwAuthorizedApplication *app) = 0;
        
        virtual /* [id] */ HRESULT STDMETHODCALLTYPE Remove( 
            /* [in] */ BSTR imageFileName) = 0;
        
        virtual /* [id] */ HRESULT STDMETHODCALLTYPE Item( 
            /* [in] */ BSTR imageFileName,
            /* [retval][out] */ INetFwAuthorizedApplication **app) = 0;
        
        virtual /* [restricted][propget][id] */ HRESULT STDMETHODCALLTYPE get__NewEnum( 
            /* [retval][out] */ IUnknown **newEnum) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct INetFwAuthorizedApplicationsVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE *QueryInterface )( 
            INetFwAuthorizedApplications * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void **ppvObject);
        
        ULONG ( STDMETHODCALLTYPE *AddRef )( 
            INetFwAuthorizedApplications * This);
        
        ULONG ( STDMETHODCALLTYPE *Release )( 
            INetFwAuthorizedApplications * This);
        
        HRESULT ( STDMETHODCALLTYPE *GetTypeInfoCount )( 
            INetFwAuthorizedApplications * This,
            /* [out] */ UINT *pctinfo);
        
        HRESULT ( STDMETHODCALLTYPE *GetTypeInfo )( 
            INetFwAuthorizedApplications * This,
            /* [in] */ UINT iTInfo,
            /* [in] */ LCID lcid,
            /* [out] */ ITypeInfo **ppTInfo);
        
        HRESULT ( STDMETHODCALLTYPE *GetIDsOfNames )( 
            INetFwAuthorizedApplications * This,
            /* [in] */ REFIID riid,
            /* [size_is][in] */ LPOLESTR *rgszNames,
            /* [in] */ UINT cNames,
            /* [in] */ LCID lcid,
            /* [size_is][out] */ DISPID *rgDispId);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE *Invoke )( 
            INetFwAuthorizedApplications * This,
            /* [in] */ DISPID dispIdMember,
            /* [in] */ REFIID riid,
            /* [in] */ LCID lcid,
            /* [in] */ WORD wFlags,
            /* [out][in] */ DISPPARAMS *pDispParams,
            /* [out] */ VARIANT *pVarResult,
            /* [out] */ EXCEPINFO *pExcepInfo,
            /* [out] */ UINT *puArgErr);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_Count )( 
            INetFwAuthorizedApplications * This,
            /* [retval][out] */ long *count);
        
        /* [id] */ HRESULT ( STDMETHODCALLTYPE *Add )( 
            INetFwAuthorizedApplications * This,
            /* [in] */ INetFwAuthorizedApplication *app);
        
        /* [id] */ HRESULT ( STDMETHODCALLTYPE *Remove )( 
            INetFwAuthorizedApplications * This,
            /* [in] */ BSTR imageFileName);
        
        /* [id] */ HRESULT ( STDMETHODCALLTYPE *Item )( 
            INetFwAuthorizedApplications * This,
            /* [in] */ BSTR imageFileName,
            /* [retval][out] */ INetFwAuthorizedApplication **app);
        
        /* [restricted][propget][id] */ HRESULT ( STDMETHODCALLTYPE *get__NewEnum )( 
            INetFwAuthorizedApplications * This,
            /* [retval][out] */ IUnknown **newEnum);
        
        END_INTERFACE
    } INetFwAuthorizedApplicationsVtbl;

    interface INetFwAuthorizedApplications
    {
        CONST_VTBL struct INetFwAuthorizedApplicationsVtbl *lpVtbl;
    };

    

#ifdef COBJMACROS


#define INetFwAuthorizedApplications_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define INetFwAuthorizedApplications_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define INetFwAuthorizedApplications_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define INetFwAuthorizedApplications_GetTypeInfoCount(This,pctinfo)	\
    (This)->lpVtbl -> GetTypeInfoCount(This,pctinfo)

#define INetFwAuthorizedApplications_GetTypeInfo(This,iTInfo,lcid,ppTInfo)	\
    (This)->lpVtbl -> GetTypeInfo(This,iTInfo,lcid,ppTInfo)

#define INetFwAuthorizedApplications_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)	\
    (This)->lpVtbl -> GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)

#define INetFwAuthorizedApplications_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)	\
    (This)->lpVtbl -> Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)


#define INetFwAuthorizedApplications_get_Count(This,count)	\
    (This)->lpVtbl -> get_Count(This,count)

#define INetFwAuthorizedApplications_Add(This,app)	\
    (This)->lpVtbl -> Add(This,app)

#define INetFwAuthorizedApplications_Remove(This,imageFileName)	\
    (This)->lpVtbl -> Remove(This,imageFileName)

#define INetFwAuthorizedApplications_Item(This,imageFileName,app)	\
    (This)->lpVtbl -> Item(This,imageFileName,app)

#define INetFwAuthorizedApplications_get__NewEnum(This,newEnum)	\
    (This)->lpVtbl -> get__NewEnum(This,newEnum)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwAuthorizedApplications_get_Count_Proxy( 
    INetFwAuthorizedApplications * This,
    /* [retval][out] */ long *count);


void __RPC_STUB INetFwAuthorizedApplications_get_Count_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [id] */ HRESULT STDMETHODCALLTYPE INetFwAuthorizedApplications_Add_Proxy( 
    INetFwAuthorizedApplications * This,
    /* [in] */ INetFwAuthorizedApplication *app);


void __RPC_STUB INetFwAuthorizedApplications_Add_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [id] */ HRESULT STDMETHODCALLTYPE INetFwAuthorizedApplications_Remove_Proxy( 
    INetFwAuthorizedApplications * This,
    /* [in] */ BSTR imageFileName);


void __RPC_STUB INetFwAuthorizedApplications_Remove_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [id] */ HRESULT STDMETHODCALLTYPE INetFwAuthorizedApplications_Item_Proxy( 
    INetFwAuthorizedApplications * This,
    /* [in] */ BSTR imageFileName,
    /* [retval][out] */ INetFwAuthorizedApplication **app);


void __RPC_STUB INetFwAuthorizedApplications_Item_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [restricted][propget][id] */ HRESULT STDMETHODCALLTYPE INetFwAuthorizedApplications_get__NewEnum_Proxy( 
    INetFwAuthorizedApplications * This,
    /* [retval][out] */ IUnknown **newEnum);


void __RPC_STUB INetFwAuthorizedApplications_get__NewEnum_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __INetFwAuthorizedApplications_INTERFACE_DEFINED__ */


#ifndef __INetFwProfile_INTERFACE_DEFINED__
#define __INetFwProfile_INTERFACE_DEFINED__

/* interface INetFwProfile */
/* [dual][uuid][object] */ 


EXTERN_C const IID IID_INetFwProfile;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("174A0DDA-E9F9-449D-993B-21AB667CA456")
    INetFwProfile : public IDispatch
    {
    public:
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_Type( 
            /* [retval][out] */ NET_FW_PROFILE_TYPE *type) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_FirewallEnabled( 
            /* [retval][out] */ VARIANT_BOOL *enabled) = 0;
        
        virtual /* [propput][id] */ HRESULT STDMETHODCALLTYPE put_FirewallEnabled( 
            /* [in] */ VARIANT_BOOL enabled) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_ExceptionsNotAllowed( 
            /* [retval][out] */ VARIANT_BOOL *notAllowed) = 0;
        
        virtual /* [propput][id] */ HRESULT STDMETHODCALLTYPE put_ExceptionsNotAllowed( 
            /* [in] */ VARIANT_BOOL notAllowed) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_NotificationsDisabled( 
            /* [retval][out] */ VARIANT_BOOL *disabled) = 0;
        
        virtual /* [propput][id] */ HRESULT STDMETHODCALLTYPE put_NotificationsDisabled( 
            /* [in] */ VARIANT_BOOL disabled) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_UnicastResponsesToMulticastBroadcastDisabled( 
            /* [retval][out] */ VARIANT_BOOL *disabled) = 0;
        
        virtual /* [propput][id] */ HRESULT STDMETHODCALLTYPE put_UnicastResponsesToMulticastBroadcastDisabled( 
            /* [in] */ VARIANT_BOOL disabled) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_RemoteAdminSettings( 
            /* [retval][out] */ INetFwRemoteAdminSettings **remoteAdminSettings) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_IcmpSettings( 
            /* [retval][out] */ INetFwIcmpSettings **icmpSettings) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_GloballyOpenPorts( 
            /* [retval][out] */ INetFwOpenPorts **openPorts) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_Services( 
            /* [retval][out] */ INetFwServices **services) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_AuthorizedApplications( 
            /* [retval][out] */ INetFwAuthorizedApplications **apps) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct INetFwProfileVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE *QueryInterface )( 
            INetFwProfile * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void **ppvObject);
        
        ULONG ( STDMETHODCALLTYPE *AddRef )( 
            INetFwProfile * This);
        
        ULONG ( STDMETHODCALLTYPE *Release )( 
            INetFwProfile * This);
        
        HRESULT ( STDMETHODCALLTYPE *GetTypeInfoCount )( 
            INetFwProfile * This,
            /* [out] */ UINT *pctinfo);
        
        HRESULT ( STDMETHODCALLTYPE *GetTypeInfo )( 
            INetFwProfile * This,
            /* [in] */ UINT iTInfo,
            /* [in] */ LCID lcid,
            /* [out] */ ITypeInfo **ppTInfo);
        
        HRESULT ( STDMETHODCALLTYPE *GetIDsOfNames )( 
            INetFwProfile * This,
            /* [in] */ REFIID riid,
            /* [size_is][in] */ LPOLESTR *rgszNames,
            /* [in] */ UINT cNames,
            /* [in] */ LCID lcid,
            /* [size_is][out] */ DISPID *rgDispId);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE *Invoke )( 
            INetFwProfile * This,
            /* [in] */ DISPID dispIdMember,
            /* [in] */ REFIID riid,
            /* [in] */ LCID lcid,
            /* [in] */ WORD wFlags,
            /* [out][in] */ DISPPARAMS *pDispParams,
            /* [out] */ VARIANT *pVarResult,
            /* [out] */ EXCEPINFO *pExcepInfo,
            /* [out] */ UINT *puArgErr);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_Type )( 
            INetFwProfile * This,
            /* [retval][out] */ NET_FW_PROFILE_TYPE *type);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_FirewallEnabled )( 
            INetFwProfile * This,
            /* [retval][out] */ VARIANT_BOOL *enabled);
        
        /* [propput][id] */ HRESULT ( STDMETHODCALLTYPE *put_FirewallEnabled )( 
            INetFwProfile * This,
            /* [in] */ VARIANT_BOOL enabled);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_ExceptionsNotAllowed )( 
            INetFwProfile * This,
            /* [retval][out] */ VARIANT_BOOL *notAllowed);
        
        /* [propput][id] */ HRESULT ( STDMETHODCALLTYPE *put_ExceptionsNotAllowed )( 
            INetFwProfile * This,
            /* [in] */ VARIANT_BOOL notAllowed);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_NotificationsDisabled )( 
            INetFwProfile * This,
            /* [retval][out] */ VARIANT_BOOL *disabled);
        
        /* [propput][id] */ HRESULT ( STDMETHODCALLTYPE *put_NotificationsDisabled )( 
            INetFwProfile * This,
            /* [in] */ VARIANT_BOOL disabled);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_UnicastResponsesToMulticastBroadcastDisabled )( 
            INetFwProfile * This,
            /* [retval][out] */ VARIANT_BOOL *disabled);
        
        /* [propput][id] */ HRESULT ( STDMETHODCALLTYPE *put_UnicastResponsesToMulticastBroadcastDisabled )( 
            INetFwProfile * This,
            /* [in] */ VARIANT_BOOL disabled);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_RemoteAdminSettings )( 
            INetFwProfile * This,
            /* [retval][out] */ INetFwRemoteAdminSettings **remoteAdminSettings);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_IcmpSettings )( 
            INetFwProfile * This,
            /* [retval][out] */ INetFwIcmpSettings **icmpSettings);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_GloballyOpenPorts )( 
            INetFwProfile * This,
            /* [retval][out] */ INetFwOpenPorts **openPorts);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_Services )( 
            INetFwProfile * This,
            /* [retval][out] */ INetFwServices **services);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_AuthorizedApplications )( 
            INetFwProfile * This,
            /* [retval][out] */ INetFwAuthorizedApplications **apps);
        
        END_INTERFACE
    } INetFwProfileVtbl;

    interface INetFwProfile
    {
        CONST_VTBL struct INetFwProfileVtbl *lpVtbl;
    };

    

#ifdef COBJMACROS


#define INetFwProfile_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define INetFwProfile_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define INetFwProfile_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define INetFwProfile_GetTypeInfoCount(This,pctinfo)	\
    (This)->lpVtbl -> GetTypeInfoCount(This,pctinfo)

#define INetFwProfile_GetTypeInfo(This,iTInfo,lcid,ppTInfo)	\
    (This)->lpVtbl -> GetTypeInfo(This,iTInfo,lcid,ppTInfo)

#define INetFwProfile_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)	\
    (This)->lpVtbl -> GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)

#define INetFwProfile_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)	\
    (This)->lpVtbl -> Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)


#define INetFwProfile_get_Type(This,type)	\
    (This)->lpVtbl -> get_Type(This,type)

#define INetFwProfile_get_FirewallEnabled(This,enabled)	\
    (This)->lpVtbl -> get_FirewallEnabled(This,enabled)

#define INetFwProfile_put_FirewallEnabled(This,enabled)	\
    (This)->lpVtbl -> put_FirewallEnabled(This,enabled)

#define INetFwProfile_get_ExceptionsNotAllowed(This,notAllowed)	\
    (This)->lpVtbl -> get_ExceptionsNotAllowed(This,notAllowed)

#define INetFwProfile_put_ExceptionsNotAllowed(This,notAllowed)	\
    (This)->lpVtbl -> put_ExceptionsNotAllowed(This,notAllowed)

#define INetFwProfile_get_NotificationsDisabled(This,disabled)	\
    (This)->lpVtbl -> get_NotificationsDisabled(This,disabled)

#define INetFwProfile_put_NotificationsDisabled(This,disabled)	\
    (This)->lpVtbl -> put_NotificationsDisabled(This,disabled)

#define INetFwProfile_get_UnicastResponsesToMulticastBroadcastDisabled(This,disabled)	\
    (This)->lpVtbl -> get_UnicastResponsesToMulticastBroadcastDisabled(This,disabled)

#define INetFwProfile_put_UnicastResponsesToMulticastBroadcastDisabled(This,disabled)	\
    (This)->lpVtbl -> put_UnicastResponsesToMulticastBroadcastDisabled(This,disabled)

#define INetFwProfile_get_RemoteAdminSettings(This,remoteAdminSettings)	\
    (This)->lpVtbl -> get_RemoteAdminSettings(This,remoteAdminSettings)

#define INetFwProfile_get_IcmpSettings(This,icmpSettings)	\
    (This)->lpVtbl -> get_IcmpSettings(This,icmpSettings)

#define INetFwProfile_get_GloballyOpenPorts(This,openPorts)	\
    (This)->lpVtbl -> get_GloballyOpenPorts(This,openPorts)

#define INetFwProfile_get_Services(This,services)	\
    (This)->lpVtbl -> get_Services(This,services)

#define INetFwProfile_get_AuthorizedApplications(This,apps)	\
    (This)->lpVtbl -> get_AuthorizedApplications(This,apps)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwProfile_get_Type_Proxy( 
    INetFwProfile * This,
    /* [retval][out] */ NET_FW_PROFILE_TYPE *type);


void __RPC_STUB INetFwProfile_get_Type_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwProfile_get_FirewallEnabled_Proxy( 
    INetFwProfile * This,
    /* [retval][out] */ VARIANT_BOOL *enabled);


void __RPC_STUB INetFwProfile_get_FirewallEnabled_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][id] */ HRESULT STDMETHODCALLTYPE INetFwProfile_put_FirewallEnabled_Proxy( 
    INetFwProfile * This,
    /* [in] */ VARIANT_BOOL enabled);


void __RPC_STUB INetFwProfile_put_FirewallEnabled_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwProfile_get_ExceptionsNotAllowed_Proxy( 
    INetFwProfile * This,
    /* [retval][out] */ VARIANT_BOOL *notAllowed);


void __RPC_STUB INetFwProfile_get_ExceptionsNotAllowed_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][id] */ HRESULT STDMETHODCALLTYPE INetFwProfile_put_ExceptionsNotAllowed_Proxy( 
    INetFwProfile * This,
    /* [in] */ VARIANT_BOOL notAllowed);


void __RPC_STUB INetFwProfile_put_ExceptionsNotAllowed_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwProfile_get_NotificationsDisabled_Proxy( 
    INetFwProfile * This,
    /* [retval][out] */ VARIANT_BOOL *disabled);


void __RPC_STUB INetFwProfile_get_NotificationsDisabled_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][id] */ HRESULT STDMETHODCALLTYPE INetFwProfile_put_NotificationsDisabled_Proxy( 
    INetFwProfile * This,
    /* [in] */ VARIANT_BOOL disabled);


void __RPC_STUB INetFwProfile_put_NotificationsDisabled_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwProfile_get_UnicastResponsesToMulticastBroadcastDisabled_Proxy( 
    INetFwProfile * This,
    /* [retval][out] */ VARIANT_BOOL *disabled);


void __RPC_STUB INetFwProfile_get_UnicastResponsesToMulticastBroadcastDisabled_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][id] */ HRESULT STDMETHODCALLTYPE INetFwProfile_put_UnicastResponsesToMulticastBroadcastDisabled_Proxy( 
    INetFwProfile * This,
    /* [in] */ VARIANT_BOOL disabled);


void __RPC_STUB INetFwProfile_put_UnicastResponsesToMulticastBroadcastDisabled_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwProfile_get_RemoteAdminSettings_Proxy( 
    INetFwProfile * This,
    /* [retval][out] */ INetFwRemoteAdminSettings **remoteAdminSettings);


void __RPC_STUB INetFwProfile_get_RemoteAdminSettings_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwProfile_get_IcmpSettings_Proxy( 
    INetFwProfile * This,
    /* [retval][out] */ INetFwIcmpSettings **icmpSettings);


void __RPC_STUB INetFwProfile_get_IcmpSettings_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwProfile_get_GloballyOpenPorts_Proxy( 
    INetFwProfile * This,
    /* [retval][out] */ INetFwOpenPorts **openPorts);


void __RPC_STUB INetFwProfile_get_GloballyOpenPorts_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwProfile_get_Services_Proxy( 
    INetFwProfile * This,
    /* [retval][out] */ INetFwServices **services);


void __RPC_STUB INetFwProfile_get_Services_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwProfile_get_AuthorizedApplications_Proxy( 
    INetFwProfile * This,
    /* [retval][out] */ INetFwAuthorizedApplications **apps);


void __RPC_STUB INetFwProfile_get_AuthorizedApplications_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __INetFwProfile_INTERFACE_DEFINED__ */


#ifndef __INetFwPolicy_INTERFACE_DEFINED__
#define __INetFwPolicy_INTERFACE_DEFINED__

/* interface INetFwPolicy */
/* [dual][uuid][object] */ 


EXTERN_C const IID IID_INetFwPolicy;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("D46D2478-9AC9-4008-9DC7-5563CE5536CC")
    INetFwPolicy : public IDispatch
    {
    public:
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_CurrentProfile( 
            /* [retval][out] */ INetFwProfile **profile) = 0;
        
        virtual /* [id] */ HRESULT STDMETHODCALLTYPE GetProfileByType( 
            /* [in] */ NET_FW_PROFILE_TYPE profileType,
            /* [retval][out] */ INetFwProfile **profile) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct INetFwPolicyVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE *QueryInterface )( 
            INetFwPolicy * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void **ppvObject);
        
        ULONG ( STDMETHODCALLTYPE *AddRef )( 
            INetFwPolicy * This);
        
        ULONG ( STDMETHODCALLTYPE *Release )( 
            INetFwPolicy * This);
        
        HRESULT ( STDMETHODCALLTYPE *GetTypeInfoCount )( 
            INetFwPolicy * This,
            /* [out] */ UINT *pctinfo);
        
        HRESULT ( STDMETHODCALLTYPE *GetTypeInfo )( 
            INetFwPolicy * This,
            /* [in] */ UINT iTInfo,
            /* [in] */ LCID lcid,
            /* [out] */ ITypeInfo **ppTInfo);
        
        HRESULT ( STDMETHODCALLTYPE *GetIDsOfNames )( 
            INetFwPolicy * This,
            /* [in] */ REFIID riid,
            /* [size_is][in] */ LPOLESTR *rgszNames,
            /* [in] */ UINT cNames,
            /* [in] */ LCID lcid,
            /* [size_is][out] */ DISPID *rgDispId);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE *Invoke )( 
            INetFwPolicy * This,
            /* [in] */ DISPID dispIdMember,
            /* [in] */ REFIID riid,
            /* [in] */ LCID lcid,
            /* [in] */ WORD wFlags,
            /* [out][in] */ DISPPARAMS *pDispParams,
            /* [out] */ VARIANT *pVarResult,
            /* [out] */ EXCEPINFO *pExcepInfo,
            /* [out] */ UINT *puArgErr);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_CurrentProfile )( 
            INetFwPolicy * This,
            /* [retval][out] */ INetFwProfile **profile);
        
        /* [id] */ HRESULT ( STDMETHODCALLTYPE *GetProfileByType )( 
            INetFwPolicy * This,
            /* [in] */ NET_FW_PROFILE_TYPE profileType,
            /* [retval][out] */ INetFwProfile **profile);
        
        END_INTERFACE
    } INetFwPolicyVtbl;

    interface INetFwPolicy
    {
        CONST_VTBL struct INetFwPolicyVtbl *lpVtbl;
    };

    

#ifdef COBJMACROS


#define INetFwPolicy_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define INetFwPolicy_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define INetFwPolicy_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define INetFwPolicy_GetTypeInfoCount(This,pctinfo)	\
    (This)->lpVtbl -> GetTypeInfoCount(This,pctinfo)

#define INetFwPolicy_GetTypeInfo(This,iTInfo,lcid,ppTInfo)	\
    (This)->lpVtbl -> GetTypeInfo(This,iTInfo,lcid,ppTInfo)

#define INetFwPolicy_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)	\
    (This)->lpVtbl -> GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)

#define INetFwPolicy_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)	\
    (This)->lpVtbl -> Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)


#define INetFwPolicy_get_CurrentProfile(This,profile)	\
    (This)->lpVtbl -> get_CurrentProfile(This,profile)

#define INetFwPolicy_GetProfileByType(This,profileType,profile)	\
    (This)->lpVtbl -> GetProfileByType(This,profileType,profile)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwPolicy_get_CurrentProfile_Proxy( 
    INetFwPolicy * This,
    /* [retval][out] */ INetFwProfile **profile);


void __RPC_STUB INetFwPolicy_get_CurrentProfile_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [id] */ HRESULT STDMETHODCALLTYPE INetFwPolicy_GetProfileByType_Proxy( 
    INetFwPolicy * This,
    /* [in] */ NET_FW_PROFILE_TYPE profileType,
    /* [retval][out] */ INetFwProfile **profile);


void __RPC_STUB INetFwPolicy_GetProfileByType_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __INetFwPolicy_INTERFACE_DEFINED__ */


#ifndef __INetFwMgr_INTERFACE_DEFINED__
#define __INetFwMgr_INTERFACE_DEFINED__

/* interface INetFwMgr */
/* [dual][uuid][object] */ 


EXTERN_C const IID IID_INetFwMgr;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("F7898AF5-CAC4-4632-A2EC-DA06E5111AF2")
    INetFwMgr : public IDispatch
    {
    public:
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_LocalPolicy( 
            /* [retval][out] */ INetFwPolicy **localPolicy) = 0;
        
        virtual /* [propget][id] */ HRESULT STDMETHODCALLTYPE get_CurrentProfileType( 
            /* [retval][out] */ NET_FW_PROFILE_TYPE *profileType) = 0;
        
        virtual /* [id] */ HRESULT STDMETHODCALLTYPE RestoreDefaults( void) = 0;
        
        virtual /* [id] */ HRESULT STDMETHODCALLTYPE IsPortAllowed( 
            /* [in] */ BSTR imageFileName,
            /* [in] */ NET_FW_IP_VERSION ipVersion,
            /* [in] */ LONG portNumber,
            /* [in] */ BSTR localAddress,
            /* [in] */ NET_FW_IP_PROTOCOL ipProtocol,
            /* [out] */ VARIANT *allowed,
            /* [out] */ VARIANT *restricted) = 0;
        
        virtual /* [id] */ HRESULT STDMETHODCALLTYPE IsIcmpTypeAllowed( 
            /* [in] */ NET_FW_IP_VERSION ipVersion,
            /* [in] */ BSTR localAddress,
            /* [in] */ BYTE type,
            /* [out] */ VARIANT *allowed,
            /* [out] */ VARIANT *restricted) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct INetFwMgrVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE *QueryInterface )( 
            INetFwMgr * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void **ppvObject);
        
        ULONG ( STDMETHODCALLTYPE *AddRef )( 
            INetFwMgr * This);
        
        ULONG ( STDMETHODCALLTYPE *Release )( 
            INetFwMgr * This);
        
        HRESULT ( STDMETHODCALLTYPE *GetTypeInfoCount )( 
            INetFwMgr * This,
            /* [out] */ UINT *pctinfo);
        
        HRESULT ( STDMETHODCALLTYPE *GetTypeInfo )( 
            INetFwMgr * This,
            /* [in] */ UINT iTInfo,
            /* [in] */ LCID lcid,
            /* [out] */ ITypeInfo **ppTInfo);
        
        HRESULT ( STDMETHODCALLTYPE *GetIDsOfNames )( 
            INetFwMgr * This,
            /* [in] */ REFIID riid,
            /* [size_is][in] */ LPOLESTR *rgszNames,
            /* [in] */ UINT cNames,
            /* [in] */ LCID lcid,
            /* [size_is][out] */ DISPID *rgDispId);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE *Invoke )( 
            INetFwMgr * This,
            /* [in] */ DISPID dispIdMember,
            /* [in] */ REFIID riid,
            /* [in] */ LCID lcid,
            /* [in] */ WORD wFlags,
            /* [out][in] */ DISPPARAMS *pDispParams,
            /* [out] */ VARIANT *pVarResult,
            /* [out] */ EXCEPINFO *pExcepInfo,
            /* [out] */ UINT *puArgErr);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_LocalPolicy )( 
            INetFwMgr * This,
            /* [retval][out] */ INetFwPolicy **localPolicy);
        
        /* [propget][id] */ HRESULT ( STDMETHODCALLTYPE *get_CurrentProfileType )( 
            INetFwMgr * This,
            /* [retval][out] */ NET_FW_PROFILE_TYPE *profileType);
        
        /* [id] */ HRESULT ( STDMETHODCALLTYPE *RestoreDefaults )( 
            INetFwMgr * This);
        
        /* [id] */ HRESULT ( STDMETHODCALLTYPE *IsPortAllowed )( 
            INetFwMgr * This,
            /* [in] */ BSTR imageFileName,
            /* [in] */ NET_FW_IP_VERSION ipVersion,
            /* [in] */ LONG portNumber,
            /* [in] */ BSTR localAddress,
            /* [in] */ NET_FW_IP_PROTOCOL ipProtocol,
            /* [out] */ VARIANT *allowed,
            /* [out] */ VARIANT *restricted);
        
        /* [id] */ HRESULT ( STDMETHODCALLTYPE *IsIcmpTypeAllowed )( 
            INetFwMgr * This,
            /* [in] */ NET_FW_IP_VERSION ipVersion,
            /* [in] */ BSTR localAddress,
            /* [in] */ BYTE type,
            /* [out] */ VARIANT *allowed,
            /* [out] */ VARIANT *restricted);
        
        END_INTERFACE
    } INetFwMgrVtbl;

    interface INetFwMgr
    {
        CONST_VTBL struct INetFwMgrVtbl *lpVtbl;
    };

    

#ifdef COBJMACROS


#define INetFwMgr_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define INetFwMgr_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define INetFwMgr_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define INetFwMgr_GetTypeInfoCount(This,pctinfo)	\
    (This)->lpVtbl -> GetTypeInfoCount(This,pctinfo)

#define INetFwMgr_GetTypeInfo(This,iTInfo,lcid,ppTInfo)	\
    (This)->lpVtbl -> GetTypeInfo(This,iTInfo,lcid,ppTInfo)

#define INetFwMgr_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)	\
    (This)->lpVtbl -> GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)

#define INetFwMgr_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)	\
    (This)->lpVtbl -> Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)


#define INetFwMgr_get_LocalPolicy(This,localPolicy)	\
    (This)->lpVtbl -> get_LocalPolicy(This,localPolicy)

#define INetFwMgr_get_CurrentProfileType(This,profileType)	\
    (This)->lpVtbl -> get_CurrentProfileType(This,profileType)

#define INetFwMgr_RestoreDefaults(This)	\
    (This)->lpVtbl -> RestoreDefaults(This)

#define INetFwMgr_IsPortAllowed(This,imageFileName,ipVersion,portNumber,localAddress,ipProtocol,allowed,restricted)	\
    (This)->lpVtbl -> IsPortAllowed(This,imageFileName,ipVersion,portNumber,localAddress,ipProtocol,allowed,restricted)

#define INetFwMgr_IsIcmpTypeAllowed(This,ipVersion,localAddress,type,allowed,restricted)	\
    (This)->lpVtbl -> IsIcmpTypeAllowed(This,ipVersion,localAddress,type,allowed,restricted)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwMgr_get_LocalPolicy_Proxy( 
    INetFwMgr * This,
    /* [retval][out] */ INetFwPolicy **localPolicy);


void __RPC_STUB INetFwMgr_get_LocalPolicy_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][id] */ HRESULT STDMETHODCALLTYPE INetFwMgr_get_CurrentProfileType_Proxy( 
    INetFwMgr * This,
    /* [retval][out] */ NET_FW_PROFILE_TYPE *profileType);


void __RPC_STUB INetFwMgr_get_CurrentProfileType_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [id] */ HRESULT STDMETHODCALLTYPE INetFwMgr_RestoreDefaults_Proxy( 
    INetFwMgr * This);


void __RPC_STUB INetFwMgr_RestoreDefaults_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [id] */ HRESULT STDMETHODCALLTYPE INetFwMgr_IsPortAllowed_Proxy( 
    INetFwMgr * This,
    /* [in] */ BSTR imageFileName,
    /* [in] */ NET_FW_IP_VERSION ipVersion,
    /* [in] */ LONG portNumber,
    /* [in] */ BSTR localAddress,
    /* [in] */ NET_FW_IP_PROTOCOL ipProtocol,
    /* [out] */ VARIANT *allowed,
    /* [out] */ VARIANT *restricted);


void __RPC_STUB INetFwMgr_IsPortAllowed_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [id] */ HRESULT STDMETHODCALLTYPE INetFwMgr_IsIcmpTypeAllowed_Proxy( 
    INetFwMgr * This,
    /* [in] */ NET_FW_IP_VERSION ipVersion,
    /* [in] */ BSTR localAddress,
    /* [in] */ BYTE type,
    /* [out] */ VARIANT *allowed,
    /* [out] */ VARIANT *restricted);


void __RPC_STUB INetFwMgr_IsIcmpTypeAllowed_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __INetFwMgr_INTERFACE_DEFINED__ */



#ifndef __NetFwPublicTypeLib_LIBRARY_DEFINED__
#define __NetFwPublicTypeLib_LIBRARY_DEFINED__

/* library NetFwPublicTypeLib */
/* [version][uuid] */ 













EXTERN_C const IID LIBID_NetFwPublicTypeLib;

EXTERN_C const CLSID CLSID_NetFwOpenPort;

#ifdef __cplusplus

class DECLSPEC_UUID("0CA545C6-37AD-4A6C-BF92-9F7610067EF5")
NetFwOpenPort;
#endif

EXTERN_C const CLSID CLSID_NetFwAuthorizedApplication;

#ifdef __cplusplus

class DECLSPEC_UUID("EC9846B3-2762-4A6B-A214-6ACB603462D2")
NetFwAuthorizedApplication;
#endif

EXTERN_C const CLSID CLSID_NetFwMgr;

#ifdef __cplusplus

class DECLSPEC_UUID("304CE942-6E39-40D8-943A-B913C40C9CD4")
NetFwMgr;
#endif
#endif /* __NetFwPublicTypeLib_LIBRARY_DEFINED__ */

/* Additional Prototypes for ALL interfaces */

unsigned long             __RPC_USER  BSTR_UserSize(     unsigned long *, unsigned long            , BSTR * ); 
unsigned char * __RPC_USER  BSTR_UserMarshal(  unsigned long *, unsigned char *, BSTR * ); 
unsigned char * __RPC_USER  BSTR_UserUnmarshal(unsigned long *, unsigned char *, BSTR * ); 
void                      __RPC_USER  BSTR_UserFree(     unsigned long *, BSTR * ); 

unsigned long             __RPC_USER  VARIANT_UserSize(     unsigned long *, unsigned long            , VARIANT * ); 
unsigned char * __RPC_USER  VARIANT_UserMarshal(  unsigned long *, unsigned char *, VARIANT * ); 
unsigned char * __RPC_USER  VARIANT_UserUnmarshal(unsigned long *, unsigned char *, VARIANT * ); 
void                      __RPC_USER  VARIANT_UserFree(     unsigned long *, VARIANT * ); 

/* end of Additional Prototypes */

#ifdef __cplusplus
}
#endif

#endif


