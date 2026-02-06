//
//  Lantern-Bridging-Header.h
//  Lantern
//
//  This bridging header allows Swift to call C functions exported from liblantern.dylib
//

#ifndef Lantern_Bridging_Header_h
#define Lantern_Bridging_Header_h

#include <stdint.h>
#include <stdlib.h>
#include <stddef.h>

// Callback typedefs for PlatformInterface (from liblantern.h)
typedef int32_t (*OpenTunCallback)(const char* tunOptionsJson, int32_t* fd);
typedef void (*ClearDNSCacheCallback)(void);
typedef void (*WriteLogCallback)(const char* message);
typedef int (*RestartServiceCallback)(void);
typedef void (*PostServiceCloseCallback)(void);
typedef int (*UsePlatformAutoDetectControlCallback)(void);
typedef char* (*ReadWIFIStateCallback)(void);
typedef int (*UnderNetworkExtensionCallback)(void);
typedef int (*IncludeAllNetworksCallback)(void);
typedef void (*SwiftEventCallback)(const char* eventJson);

// Go string type (for some exported functions)
typedef struct { const char *p; ptrdiff_t n; } GoString;
typedef ptrdiff_t GoInt;

// Core setup and lifecycle
extern char* setup(char* logDir, char* dataDir, char* locale,
                   int64_t logP, int64_t appsP, int64_t statusP,
                   int64_t privateServerP, int64_t appEventP,
                   int consent, void* api);

// Platform callback registration (for PacketTunnel)
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

extern void registerSwiftEventCallback(SwiftEventCallback callback);

// VPN operations with platform interface (for PacketTunnel)
extern char* startVPNWithPlatform(char* logDir, char* dataDir, char* locale);
extern char* connectToServerWithPlatform(char* location, char* tag, char* logDir, char* dataDir, char* locale);

// VPN operations (for Runner - uses Dart ports)
extern char* startVPN(char* logDir, char* dataDir, char* locale);
extern char* stopVPN(void);
extern char* connectToServer(char* location, char* tag, char* logDir, char* dataDir, char* locale);
extern int isVPNConnected(void);

// Auto location
extern char* getAutoLocation(void);
extern char* startAutoLocationListener(void);
extern char* stopAutoLocationListener(void);

// Server selection
extern char* getAvailableServers(void);

// User data and authentication
extern char* getUserData(void);
extern char* fetchUserData(void);
extern char* login(char* email, char* password);
extern char* signup(char* email, char* password);
extern char* logout(char* email);
extern char* deleteAccount(char* email, char* password);

// OAuth
extern char* oauthLoginUrl(char* provider);
extern char* oAuthLoginCallback(char* oAuthToken);

// Password recovery
extern char* startRecoveryByEmail(char* email);
extern char* validateEmailRecoveryCode(char* email, char* code);
extern char* completeRecoveryByEmail(char* email, char* newPassword, char* code);

// Email change
extern char* startChangeEmail(char* newEmail, char* password);
extern char* completeChangeEmail(char* newEmail, char* password, char* code);

// Device management
extern char* removeDevice(char* deviceId);

// Referral
extern char* referralAttachment(char* referralCode);

// Plans and payments
extern char* plans(void);
extern char* stripeSubscriptionPaymentRedirect(char* subType, char* planId, char* email);
extern char* paymentRedirect(char* plan, char* provider, char* email);
extern char* stripeBillingPortalUrl(void);
extern char* activationCode(char* email, char* resellerCode);

// Data cap
extern char* getDataCapInfo(void);

// Feature flags
extern char* availableFeatures(void);

// Locale
extern char* updateLocale(char* locale);

// Telemetry
extern char* updateTelemetryConsent(int consent);

// Issue reporting
extern char* reportIssue(char* email, char* issueType, char* description,
                         char* device, char* model, char* logPath);

// Split tunneling
extern char* addSplitTunnelItem(char* filterType, char* item);
extern char* removeSplitTunnelItem(char* filterType, char* item);
extern char* setSplitTunnelingEnabled(int enabled);
extern int isSplitTunnelingEnabled(void);
extern char* loadInstalledApps(char* dataDir);

// Block ads
extern char* setBlockAdsEnabled(int enabled);
extern int isBlockAdsEnabled(void);

// Smart routing
extern char* setSmartRoutingEnabled(int enabled);
extern int isSmartRoutingEnabled(void);

// Private server operations
extern char* digitalOceanPrivateServer(void);
extern char* googleCloudPrivateServer(void);
extern char* selectAccount(char* account);
extern char* selectProject(char* project);
extern char* validateSession(void);
extern char* startDepolyment(char* selectedLocation, char* serverName);
extern char* cancelDepolyment(void);
extern char* addServerManagerInstance(char* ip, char* port, char* accessToken, char* tag);
extern char* inviteToServerManagerInstance(char* ip, char* port, char* accessToken, char* inviteName);
extern char* revokeServerManagerInvite(char* ip, char* port, char* accessToken, char* inviteName);
extern char* addServerBasedOnURLs(char* urls, int skipCertVerification, char* serverName);

// Memory management
extern void freeCString(char* str);

#endif /* Lantern_Bridging_Header_h */
