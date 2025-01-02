// WriteToOSBridge.m
#import <Foundation/Foundation.h>
#import "Tunnel-Bridging-Header.h"

// Hold a pointer to the Swift PacketTunnelProvider (or a manager object).
static void *swiftProviderRef = NULL;

void SetSwiftProviderRef(void *providerRef) {
    swiftProviderRef = providerRef;
}

void SwiftLog(const char *message) {
    NSLog(@"message=%s", message);
}

// Function to write packets to Swift and return success indicator
int WriteToOS(const void *packetPtr, int length) {
    NSLog(@"WriteToOS called");
    if (!swiftProviderRef) {
        NSLog(@"Swift provider reference is NULL");
        return 0;
    }
    NSLog(@"Writing packet back to OS");
    NSData *packetData = [NSData dataWithBytes:packetPtr length:length];

    // Call "handleOutboundPacket:" on the Swift provider
    SEL sel = NSSelectorFromString(@"handleOutboundPacket:");
    BOOL success = NO;
    if ([(__bridge id)swiftProviderRef respondsToSelector:sel]) {
        // Use function pointer to call the selector to avoid warnings
        typedef BOOL (*Func)(id, SEL, NSData *);
        Func func = (Func)[(__bridge id)swiftProviderRef methodForSelector:sel];
        if (func) {
            success = func((__bridge id)swiftProviderRef, sel, packetData);
        }
    }

    NSLog(@"WriteToOS success: %d", success);
    return success ? 1 : 0;
}