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
    WebPreferences *prefs = [self.webView preferences];
    [prefs setPrivateBrowsingEnabled:YES];
    NSArray *arguments = [[NSProcessInfo processInfo] arguments];
    NSString *url = [arguments objectAtIndex:1];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    [self.webView.mainFrame loadRequest:request];
    [NSApp activateIgnoringOtherApps:YES];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
    return YES;
}

@end