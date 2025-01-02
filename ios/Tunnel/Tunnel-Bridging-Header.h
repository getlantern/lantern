// vpn_bridging.h
#ifndef vpn_bridging_h
#define vpn_bridging_h

void SetSwiftProviderRef(void *providerRef);

// Called by Go when it wants to send an IP packet back to iOS
extern int WriteToOS(const void *packetPtr, int length);

extern void SwiftLog(const char* message);

int StartTun2Socks(int tunFd, const char *proxyConfig);

#endif /* vpn_bridging_h */
