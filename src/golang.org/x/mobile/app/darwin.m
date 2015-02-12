// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build darwin

#include "_cgo_export.h"
#include <pthread.h>
#include <stdio.h>

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>
#import <OpenGL/gl.h>
#import <QuartzCore/CVReturn.h>
#import <QuartzCore/CVBase.h>

static CVReturn displayLinkDraw(CVDisplayLinkRef displayLink, const CVTimeStamp* now, const CVTimeStamp* outputTime, CVOptionFlags flagsIn, CVOptionFlags* flagsOut, void* displayLinkContext)
{
	NSOpenGLView* view = displayLinkContext;
	NSOpenGLContext *currentContext = [view openGLContext];
	drawgl((GLintptr)currentContext);
	return kCVReturnSuccess;
}

void lockContext(GLintptr context) {
	NSOpenGLContext* ctx = (NSOpenGLContext*)context;
	[ctx makeCurrentContext];
	CGLLockContext([ctx CGLContextObj]);
}

void unlockContext(GLintptr context) {
	NSOpenGLContext* ctx = (NSOpenGLContext*)context;
	[ctx flushBuffer];
	CGLUnlockContext([ctx CGLContextObj]);

}

uint64 threadID() {
	uint64 id;
	if (pthread_threadid_np(pthread_self(), &id)) {
		abort();
	}
	return id;
}


@interface MobileGLView : NSOpenGLView
{
	CVDisplayLinkRef displayLink;
}
@end

@implementation MobileGLView
- (void)prepareOpenGL {
	[self setWantsBestResolutionOpenGLSurface:YES];
	GLint swapInt = 1;
	[[self openGLContext] setValues:&swapInt forParameter:NSOpenGLCPSwapInterval];

	CVDisplayLinkCreateWithActiveCGDisplays(&displayLink);
	CVDisplayLinkSetOutputCallback(displayLink, &displayLinkDraw, self);

	CGLContextObj cglContext = [[self openGLContext] CGLContextObj];
	CGLPixelFormatObj cglPixelFormat = [[self pixelFormat] CGLPixelFormatObj];
	CVDisplayLinkSetCurrentCGDisplayFromOpenGLContext(displayLink, cglContext, cglPixelFormat);
	CVDisplayLinkStart(displayLink);
}

- (void)reshape {
	// Calculate screen PPI.
	//
	// Note that the backingScaleFactor converts from logical
	// pixels to actual pixels, but both of these units vary
	// independently from real world size. E.g.
	//
	// 13" Retina Macbook Pro, 2560x1600, 227ppi, backingScaleFactor=2, scale=3.15
	// 15" Retina Macbook Pro, 2880x1800, 220ppi, backingScaleFactor=2, scale=3.06
	// 27" iMac,               2560x1440, 109ppi, backingScaleFactor=1, scale=1.51
	// 27" Retina iMac,        5120x2880, 218ppi, backingScaleFactor=2, scale=3.03
	NSScreen *screen = [NSScreen mainScreen];
	double screenPixW = [screen frame].size.width * [screen backingScaleFactor];

	CGDirectDisplayID display = (CGDirectDisplayID)[[[screen deviceDescription] valueForKey:@"NSScreenNumber"] intValue];
	CGSize screenSizeMM = CGDisplayScreenSize(display); // in millimeters
	float ppi = 25.4 * screenPixW / screenSizeMM.width;
	float pixelsPerPt = ppi/72.0;

	// The width and height reported to the geom package are the
	// bounds of the OpenGL view. Several steps are necessary.
	// First, [self bounds] gives us the number of logical pixels
	// in the view. Multiplying this by the backingScaleFactor
	// gives us the number of actual pixels.
	NSRect r = [self bounds];
	int w = r.size.width * [screen backingScaleFactor];
	int h = r.size.height * [screen backingScaleFactor];

	setGeom(pixelsPerPt, w, h);
}

- (void)mouseDown:(NSEvent *)theEvent {
	double scale = [[NSScreen mainScreen] backingScaleFactor];
	NSPoint p = [theEvent locationInWindow];
	eventMouseDown(p.x * scale, p.y * scale);
}

- (void)mouseUp:(NSEvent *)theEvent {
	double scale = [[NSScreen mainScreen] backingScaleFactor];
	NSPoint p = [theEvent locationInWindow];
	eventMouseEnd(p.x * scale, p.y * scale);
}

- (void)mouseDragged:(NSEvent *)theEvent {
	double scale = [[NSScreen mainScreen] backingScaleFactor];
	NSPoint p = [theEvent locationInWindow];
	eventMouseDragged(p.x * scale, p.y * scale);
}
@end

void
runApp(void) {
	[NSAutoreleasePool new];
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

	id menuBar = [[NSMenu new] autorelease];
	id menuItem = [[NSMenuItem new] autorelease];
	[menuBar addItem:menuItem];
	[NSApp setMainMenu:menuBar];

	id menu = [[NSMenu new] autorelease];
	id name = [[NSProcessInfo processInfo] processName];
	id quitMenuItem = [[[NSMenuItem alloc] initWithTitle:@"Quit"
		action:@selector(terminate:) keyEquivalent:@"q"]
		autorelease];
	[menu addItem:quitMenuItem];
	[menuItem setSubmenu:menu];

	NSRect rect = NSMakeRect(0, 0, 400, 400);

	id window = [[[NSWindow alloc] initWithContentRect:rect
			styleMask:NSTitledWindowMask
			backing:NSBackingStoreBuffered
			defer:NO]
		autorelease];
	[window setStyleMask:[window styleMask] | NSResizableWindowMask];
	[window cascadeTopLeftFromPoint:NSMakePoint(20,20)];
	[window makeKeyAndOrderFront:nil];
	[window setTitle:name];

	NSOpenGLPixelFormatAttribute attr[] = {
		NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core,
		NSOpenGLPFAColorSize,     24,
		NSOpenGLPFAAlphaSize,     8,
		NSOpenGLPFADepthSize,     16,
		NSOpenGLPFAAccelerated,
		NSOpenGLPFADoubleBuffer,
		0
	};
	id pixFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attr];
	id view = [[MobileGLView alloc] initWithFrame:rect pixelFormat:pixFormat];
	[window setContentView:view];

	[NSApp activateIgnoringOtherApps:YES];
	[NSApp run];
}
