/** Configures the Lantern network proxy on all interfaces.
 
 By Leah X Schmidt
 Copyright 2013, Brave New Software
 
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
 
 */
#import <Foundation/NSArray.h>
#import <Foundation/Foundation.h>
#import <SystemConfiguration/SCPreferences.h>
#import <SystemConfiguration/SCNetworkConfiguration.h>


void toggleAutoProxyConfigFile(NSString *onOff, NSString *autoProxyConfigFileUrl)
{
    
    NSLog(@"Toggle %@ auto proxy configuration file to %@", onOff, autoProxyConfigFileUrl);
    BOOL success = FALSE;
    
    SCNetworkSetRef networkSetRef;
    CFArrayRef networkServicesArrayRef;
    SCNetworkServiceRef networkServiceRef;
    SCNetworkProtocolRef proxyProtocolRef;
    NSDictionary *oldPreferences;
    NSMutableDictionary *newPreferences;
    NSString *wantedHost;
    
    
    // Get System Preferences Lock
    SCPreferencesRef prefsRef = SCPreferencesCreate(NULL, CFSTR("org.getlantern.lantern"), NULL);
    
    if(prefsRef==NULL) {
        NSLog(@"Fail to obtain Preferences Ref!!");
        goto freePrefsRef;
    }
    
    success = SCPreferencesLock(prefsRef, TRUE);
    if (!success) {
        NSLog(@"Fail to obtain PreferencesLock");
        goto freePrefsRef;
    }
    
    // Get available network services
    networkSetRef = SCNetworkSetCopyCurrent(prefsRef);
    if(networkSetRef == NULL) {
        NSLog(@"Fail to get available network services");
        goto freeNetworkSetRef;
    }
    
    //Look up interface entry
    networkServicesArrayRef = SCNetworkSetCopyServices(networkSetRef);
    networkServiceRef = NULL;
    for (long i = 0; i < CFArrayGetCount(networkServicesArrayRef); i++) {
        networkServiceRef = CFArrayGetValueAtIndex(networkServicesArrayRef, i);
        NSLog(@"Setting proxy for device %@", SCNetworkServiceGetName(networkServiceRef));
        
        // Get proxy protocol
        proxyProtocolRef = SCNetworkServiceCopyProtocol(networkServiceRef, kSCNetworkProtocolTypeProxies);
        if(proxyProtocolRef == NULL) {
            NSLog(@"Couldn't acquire copy of proxyProtocol");
            goto freeProxyProtocolRef;
        }
        
        oldPreferences = (__bridge NSDictionary*)SCNetworkProtocolGetConfiguration(proxyProtocolRef);
        newPreferences = [NSMutableDictionary dictionaryWithDictionary: oldPreferences];
        wantedHost = @"localhost";
        
        if([onOff  isEqual: @"on"]) {//Turn proxy configuration ON
            [newPreferences setValue: wantedHost forKey:(NSString*)kSCPropNetProxiesHTTPProxy];
            [newPreferences setValue:[NSNumber numberWithInt:1] forKey:(NSString*)kSCPropNetProxiesProxyAutoConfigEnable];
            [newPreferences setValue:autoProxyConfigFileUrl forKey:(NSString*)kSCPropNetProxiesProxyAutoConfigURLString];
            NSLog(@"Setting Proxy ON with: %@", newPreferences);
        } else {//Turn proxy configuration OFF
            [newPreferences setValue:[NSNumber numberWithInt:0] forKey:(NSString*)kSCPropNetProxiesProxyAutoConfigEnable];
            NSLog(@"Setting Proxy OFF");
        }
        
        success = SCNetworkProtocolSetConfiguration(proxyProtocolRef, (__bridge CFDictionaryRef)newPreferences);
        if(!success) {
            NSLog(@"Failed to set Protocol Configuration");
            goto freeProxyProtocolRef;
        }
        
    freeProxyProtocolRef:
        CFRelease(proxyProtocolRef);
    }
    
    success = SCPreferencesCommitChanges(prefsRef);
    if(!success) {
        NSLog(@"Failed to Commit Changes");
        goto freeNetworkServicesArrayRef;
    }
    
    success = SCPreferencesApplyChanges(prefsRef);
    if(!success) {
        NSLog(@"Failed to Apply Changes");
        goto freeNetworkServicesArrayRef;
    }
    //Free Resources
freeNetworkServicesArrayRef:
    CFRelease(networkServicesArrayRef);
freeNetworkSetRef:
    CFRelease(networkSetRef);
freePrefsRef:
    SCPreferencesUnlock(prefsRef);
    CFRelease(prefsRef);
    
    return;
}


int main() {
    NSArray *args = [[NSProcessInfo processInfo] arguments];
    
    // Become root in order to support reconfiguring network services
    setuid(0);
    
    toggleAutoProxyConfigFile([args objectAtIndex:1],
                              [args objectAtIndex:2]);
    
    return 0;
}
