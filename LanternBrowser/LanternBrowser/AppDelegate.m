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