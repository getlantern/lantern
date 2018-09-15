// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build ignore

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import "benchmark/Benchmark.h"

@interface AnI : NSObject <GoBenchmarkI> {
}
@end

@implementation AnI
- (void)f {
}
@end

@interface Benchmarks : NSObject <GoBenchmarkBenchmarks> {
}
@end

@implementation Benchmarks
- (void)manyargs:(int)p0 p1:(int)p1 p2:(int)p2 p3:(int)p3 p4:(int)p4 p5:(int)p5 p6:(int)p6 p7:(int)p7 p8:(int)p8 p9:(int)p9 {
}

- (id<GoBenchmarkI>)newI {
	return [[AnI alloc] init];
}

- (void)noargs {
}

- (void)onearg:(int)p0 {
}

- (int)oneret {
	return 0;
}

- (void)ref:(id<GoBenchmarkI>)p0 {
}

- (void)slice:(NSData*)p0 {
}

- (void)string:(NSString*)p0 {
}

- (NSString*)stringRetLong {
	return GoBenchmarkLongString;
}

- (NSString*)stringRetShort {
	return GoBenchmarkShortString;
}

- (void (^)(void))lookupBenchmark:(NSString *)name {
	if ([name isEqualToString:@"Empty"]) {
		return ^() {
		};
	} else if ([name isEqualToString:@"Noargs"]) {
		return ^() {
			GoBenchmarkNoargs();
		};
	} else if ([name isEqualToString:@"Onearg"]) {
		return ^() {
			GoBenchmarkOnearg(0);
		};
	} else if ([name isEqualToString:@"Manyargs"]) {
		return ^() {
			GoBenchmarkManyargs(0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
		};
	} else if ([name isEqualToString:@"Oneret"]) {
		return ^() {
			GoBenchmarkOneret();
		};
	} else if ([name isEqualToString:@"Refforeign"]) {
		id<GoBenchmarkI> objcRef = [[AnI alloc] init];
		return ^() {
			GoBenchmarkRef(objcRef);
		};
	} else if ([name isEqualToString:@"Refgo"]) {
		id<GoBenchmarkI> goRef = GoBenchmarkNewI();
		return ^() {
			GoBenchmarkRef(goRef);
		};
	} else if ([name isEqualToString:@"StringShort"]) {
		return ^() {
			GoBenchmarkString(GoBenchmarkShortString);
		};
	} else if ([name isEqualToString:@"StringLong"]) {
		return ^() {
			GoBenchmarkString(GoBenchmarkLongString);
		};
	} else if ([name isEqualToString:@"StringShortUnicode"]) {
		return ^() {
			GoBenchmarkString(GoBenchmarkShortStringUnicode);
		};
	} else if ([name isEqualToString:@"StringLongUnicode"]) {
		return ^() {
			GoBenchmarkString(GoBenchmarkLongStringUnicode);
		};
	} else if ([name isEqualToString:@"StringRetShort"]) {
		return ^() {
			GoBenchmarkStringRetShort();
		};
	} else if ([name isEqualToString:@"StringRetLong"]) {
		return ^() {
			GoBenchmarkStringRetLong();
		};
	} else if ([name isEqualToString:@"SliceShort"]) {
		NSData *s = [GoBenchmark shortSlice];
		return ^() {
			GoBenchmarkSlice(s);
		};
	} else if ([name isEqualToString:@"SliceLong"]) {
		NSData *s = [GoBenchmark longSlice];
		return ^() {
			GoBenchmarkSlice(s);
		};
	} else {
		return nil;
	}
}

- (void)run:(NSString*)name n:(int)n {
	void (^bench)(void) = [self lookupBenchmark:name];
	if (bench == nil) {
		NSLog(@"Error: no such benchmark: %@", name);
		return;
	}
	for (int i = 0; i < n; i++) {
		bench();
	}
}

- (void)runDirect:(NSString*)name n:(int)n {
	void (^bench)(void) = [self lookupBenchmark:name];
	if (bench == nil) {
		NSLog(@"Error: no such benchmark: %@", name);
		return;
	}
	dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		for (int i = 0; i < n; i++) {
			bench();
		}
	});
}

@end

@interface benchmarks : XCTestCase

@end

@implementation benchmarks

- (void)setUp {
	[super setUp];

	// Put setup code here. This method is called before the invocation of each test method in the class.

	// In UI tests it is usually best to stop immediately when a failure occurs.
	self.continueAfterFailure = NO;
	// UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
	[[[XCUIApplication alloc] init] launch];

	// In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
}

- (void)tearDown {
	// Put teardown code here. This method is called after the invocation of each test method in the class.
	[super tearDown];
}

- (void)testBenchmark {
	// Long running unit tests seem to hang. Use an XCTestExpectation and run the Go
	// benchmark suite on a GCD thread.
	XCTestExpectation *expectation =
		[self expectationWithDescription:@"Benchmark"];

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		Benchmarks *b = [[Benchmarks alloc] init];
		GoBenchmarkRunBenchmarks(b);
		[expectation fulfill];
	});

	[self waitForExpectationsWithTimeout:5*60.0 handler:^(NSError *error) {
		if (error) {
			NSLog(@"Timeout Error: %@", error);
		}
	}];
}
@end
