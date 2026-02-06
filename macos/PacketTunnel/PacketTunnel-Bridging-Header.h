//
//  PacketTunnel-Bridging-Header.h
//  PacketTunnel
//
//  This bridging header allows Swift to call C functions exported from liblantern.dylib
//  for the PacketTunnel network extension.
//

#ifndef PacketTunnel_Bridging_Header_h
#define PacketTunnel_Bridging_Header_h

#include <stdint.h>
#include <stdlib.h>
#include <stddef.h>

// Callback typedefs for PlatformInterface
typedef int32_t (*OpenTunCallback)(const char* tunOptionsJson, int32_t* fd);
typedef void (*ClearDNSCacheCallback)(void);
typedef void (*WriteLogCallback)(const char* message);
typedef int (*RestartServiceCallback)(void);
typedef void (*PostServiceCloseCallback)(void);
typedef int (*UsePlatformAutoDetectControlCallback)(void);
typedef char* (*ReadWIFIStateCallback)(void);
typedef int (*UnderNetworkExtensionCallback)(void);
typedef int (*IncludeAllNetworksCallback)(void);

// Platform callback registration
extern void registerPlatformCallbacks(
    OpenTunCallback openTun,
    ClearDNSCacheCallback clearDNSCache,
    WriteLogCallback writeLog,
    RestartServiceCallback restartService,
    PostServiceCloseCallback postServiceClose,
    UsePlatformAutoDetectControlCallback usePlatformAutoDetectControl,
    ReadWIFIStateCallback readWIFIState,
    UnderNetworkExtensionCallback underNetworkExtension,
    IncludeAllNetworksCallback includeAllNetworks
);

// VPN operations with platform interface (for PacketTunnel)
extern char* startVPNWithPlatform(char* logDir, char* dataDir, char* locale);
extern char* connectToServerWithPlatform(char* location, char* tag, char* logDir, char* dataDir, char* locale);
extern char* stopVPN(void);

// Memory management
extern void freeCString(char* str);

#endif /* PacketTunnel_Bridging_Header_h */
