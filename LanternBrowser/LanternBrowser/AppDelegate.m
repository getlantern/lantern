//
//  AppDelegate.m
//  LanternBrowser
//
//  Created by Leah Schmidt on 5/21/13.
//  Copyright (c) 2013 Brave New Software. All rights reserved.
//

#import "AppDelegate.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self.webView setPreferencesIdentifier:@"Lantern"];
    //WebPreferences *prefs = [self.webView preferences];
    //[prefs setPrivateBrowsingEnabled:YES];
    NSArray *arguments = [[NSProcessInfo processInfo] arguments];
    NSString *url = [arguments objectAtIndex:1];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    [self.webView.mainFrame loadRequest:request];
    [NSApp activateIgnoringOtherApps:YES];
    [self.webView setPolicyDelegate:self];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
    return YES;
}

//
// Implementing this (and registering it with [self.webView setPolicyDelegate:self]) allows us to find out about people clicking on links with
// target = "_blank" and then open these.  We open them in Safari and always force a new instance (window) as opposed to a new tab.
// Note - for whatever reason, when using window.open(), the request comes in as null, so only target = "_blank" actually works.
- (void)webView:(WebView *)webView decidePolicyForNewWindowAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request newFrameName:(NSString *)frameName decisionListener:(id < WebPolicyDecisionListener >)listener {
    NSURL* url = request.URL;
    NSLog(@"Got request to open url: %@", [url description]);
    [[NSWorkspace sharedWorkspace] openURLs:@[url]
                    withAppBundleIdentifier:@"com.apple.Safari"
                                    options:NSWorkspaceLaunchNewInstance
             additionalEventParamDescriptor:nil
                          launchIdentifiers:nil];
}

@end