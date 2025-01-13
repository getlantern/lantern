// WriteToOSBridge.m
#import <Foundation/Foundation.h>
#import "Tunnel-Bridging-Header.h"

// Hold a pointer to the Swift PacketTunnelProvider
static void *swiftProviderRef = NULL;

void SetSwiftProviderRef(void *providerRef) {
    swiftProviderRef = providerRef;
}

void SwiftLog(const char *message) {
    NSLog(@"message=%s", message);
}

// Called by Go when it wants to send an IP packet back to iOS
int WriteToOS(const void *packetPtr, int length) {
    if (!swiftProviderRef) {
        NSLog(@"Swift provider reference is NULL");
        return 0;
    }
    NSData *packetData = [NSData dataWithBytes:packetPtr length:length];
    // Call "handleOutboundPacket:" on the Swift provider
    SEL sel = NSSelectorFromString(@"handleOutboundPacket:");
    BOOL success = NO;
    if ([(__bridge id)swiftProviderRef respondsToSelector:sel]) {
        // Use function pointer here to call the selector to avoid warnings
        typedef BOOL (*Func)(id, SEL, NSData *);
        Func func = (Func)[(__bridge id)swiftProviderRef methodForSelector:sel];
        if (func) {
            success = func((__bridge id)swiftProviderRef, sel, packetData);
        }
    }
    return success ? 1 : 0;
}