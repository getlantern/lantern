// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build darwin

#include "_cgo_export.h"
#include <pthread.h>
#include <stdio.h>
#include <sys/utsname.h>

#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>

struct utsname sysInfo;

@interface AppController : GLKViewController
@end

@interface AppDelegate : UIResponder<UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) AppController *controller;
@end

@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	self.controller = [[AppController alloc] initWithNibName:nil bundle:nil];
	self.window.rootViewController = self.controller;
	[self.window makeKeyAndVisible];
	return YES;
}
@end

@interface AppController ()
@property (strong, nonatomic) EAGLContext *context;
@end

@implementation AppController
- (void)viewDidLoad {
	[super viewDidLoad];
	self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
	GLKView *view = (GLKView *)self.view;
	view.context = self.context;
	view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
}
- (void)update {
	GLKView *view = (GLKView *)self.view;
	int w = [view drawableWidth];
	int h = [view drawableHeight];
	setGeom(w, h);

	drawgl((GoUintptr)self.context);
}
@end

void runApp(void) {
	@autoreleasepool {
		UIApplicationMain(0, nil, nil, NSStringFromClass([AppDelegate class]));
	}
}

void setContext(void* context) {
	EAGLContext* ctx = (EAGLContext*)context;
	if (![EAGLContext setCurrentContext:ctx]) {
		// TODO(crawshaw): determine how terrible this is. Exit?
		NSLog(@"failed to set current context");
	}
}

uint64_t threadID() {
	uint64_t id;
	if (pthread_threadid_np(pthread_self(), &id)) {
		abort();
	}
	return id;
}
