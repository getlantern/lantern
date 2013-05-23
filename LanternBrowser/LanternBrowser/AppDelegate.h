//
//  AppDelegate.h
//  LanternBrowser
//
//  Created by Leah Schmidt on 5/21/13.
//  Copyright (c) 2013 Brave New Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface AppDelegate : NSObject <NSApplicationDelegate> 

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet WebView *webView;


@end
