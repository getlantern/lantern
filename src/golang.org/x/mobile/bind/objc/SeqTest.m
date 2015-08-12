// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build ignore

#import <Foundation/Foundation.h>
#import "GoTestpkg.h"

#define ERROR(...)                                                             \
  do {                                                                         \
    NSLog(__VA_ARGS__);                                                        \
    err = 1;                                                                   \
  } while (0);

static int err = 0;

void testHello(NSString *input) {
  NSString *got = GoTestpkgHello(input);
  NSString *want = [NSString stringWithFormat:@"Hello, %@!", input];
  if (!got) {
    ERROR(@"GoTestpkgHello(%@)= NULL, want %@", input, want);
    return;
  }
  if (![got isEqualToString:want]) {
    ERROR(@"want %@\nGoTestpkgHello(%@)= %@", want, input, got);
  }
}

void testBytesAppend(NSString *a, NSString *b) {
  NSData *data_a = [a dataUsingEncoding:NSUTF8StringEncoding];
  NSData *data_b = [b dataUsingEncoding:NSUTF8StringEncoding];
  NSData *gotData = GoTestpkgBytesAppend(data_a, data_b);
  NSString *got =
      [[NSString alloc] initWithData:gotData encoding:NSUTF8StringEncoding];
  NSString *want = [a stringByAppendingString:b];
  if (![got isEqualToString:want]) {
    ERROR(@"want %@\nGoTestpkgBytesAppend(%@, %@) = %@", want, a, b, got);
  }
}

void testReturnsError() {
  NSString *value;
  NSError *error;
  GoTestpkgReturnsError(TRUE, &value, &error);
  NSString *got = [error.userInfo valueForKey:NSLocalizedDescriptionKey];
  NSString *want = @"Error";
  if (![got isEqualToString:want]) {
    ERROR(@"want %@\nGoTestpkgReturnsError(TRUE) = (%@, %@)", want, value, got);
  }
}

void testStruct() {
  GoTestpkgS *s = GoTestpkgNewS(10.0, 100.0);
  if (!s) {
    ERROR(@"GoTestpkgNewS returned NULL");
  }

  double x = [s X];
  double y = [s Y];
  double sum = [s Sum];
  if (x != 10.0 || y != 100.0 || sum != 110.0) {
    ERROR(@"GoTestpkgS(10.0, 100.0).X=%f Y=%f SUM=%f; want 10, 100, 110", x, y,
          sum);
  }

  double sum2 = GoTestpkgCallSSum(s);
  if (sum != sum2) {
    ERROR(@"GoTestpkgCallSSum(s)=%f; want %f as returned by s.Sum", sum2, sum);
  }

  [s setX:7];
  [s setY:70];
  x = [s X];
  y = [s Y];
  sum = [s Sum];
  if (x != 7 || y != 70 || sum != 77) {
    ERROR(@"GoTestpkgS(7, 70).X=%f Y=%f SUM=%f; want 7, 70, 77", x, y, sum);
  }

  NSString *first = @"trytwotested";
  NSString *second = @"test";
  NSString *got = [s TryTwoStrings:first second:second];
  NSString *want = [first stringByAppendingString:second];
  if (![got isEqualToString:want]) {
    ERROR(@"GoTestpkgS_TryTwoStrings(%@, %@)= %@; want %@", first, second, got,
          want);
  }

  GoTestpkgGC();
}

// Objective-C implementation of testpkg.I.
@interface Number : NSObject <GoTestpkgI> {
}
@property int32_t value;

- (int64_t)Times:(int32_t)v;
@end

// numI is incremented when the first numI objective-C implementation is
// deallocated.
static int numI = 0;

@implementation Number {
}
@synthesize value;

- (int64_t)Times:(int32_t)v {
  return v * value;
}
- (void)dealloc {
  if (self.value == 0) {
    numI++;
  }
}
@end

void testInterface() {
  // Test Go object implementing testpkg.I is handled correctly.
  id<GoTestpkgI> goObj = GoTestpkgNewI();
  int64_t got = [goObj Times:10];
  if (got != 100) {
    ERROR(@"GoTestpkgNewI().Times(10) = %lld; want %d", got, 100);
  }
  int32_t key = -1;
  GoTestpkgRegisterI(key, goObj);
  int64_t got2 = GoTestpkgMultiply(key, 10);
  if (got != got2) {
    ERROR(@"GoTestpkgMultiply(10 * 10) = %lld; want %lld", got2, got);
  }
  GoTestpkgUnregisterI(key);

  // Test Objective-C objects implementing testpkg.I is handled correctly.
  @autoreleasepool {
    for (int32_t i = 0; i < 10; i++) {
      Number *num = [[Number alloc] init];
      num.value = i;
      GoTestpkgRegisterI(i, num);
    }
    GoTestpkgGC();
  }

  // Registered Objective-C objects are pinned on Go side which must
  // prevent deallocation from Objective-C.
  for (int32_t i = 0; i < 10; i++) {
    int64_t got = GoTestpkgMultiply(i, 2);
    if (got != i * 2) {
      ERROR(@"GoTestpkgMultiply(%d, 2) = %lld; want %d", i, got, i * 2);
      return;
    }
    GoTestpkgUnregisterI(i);
    GoTestpkgGC();
  }
  // Unregistered all Objective-C objects.
}

// Invokes functions and object methods defined in Testpkg.h.
//
// TODO(hyangah): apply testing framework (e.g. XCTestCase)
// and test through xcodebuild.
int main(void) {
  @autoreleasepool {
    GoTestpkgHi();

    GoTestpkgInt(42);

    int64_t sum = GoTestpkgSum(31, 21);
    if (sum != 52) {
      ERROR(@"GoTestpkgSum(31, 21) = %lld, want 52\n", sum);
    }

    testHello(@"세계"); // korean, utf-8, world.

    unichar t[] = {
        0xD83D, 0xDCA9,
    }; // utf-16, pile of poo.
    testHello([NSString stringWithCharacters:t length:2]);

    testBytesAppend(@"Foo", @"Bar");

    testStruct();
    int numS = GoTestpkgCollectS(
        1, 10); // within 10 seconds, collect the S used in testStruct.
    if (numS != 1) {
      ERROR(@"%d S objects were collected; S used in testStruct is supposed to "
            @"be collected.",
            numS);
    }

    @autoreleasepool {
      testInterface();
    }
    if (numI != 1) {
      ERROR(@"%d I objects were collected; I used in testInterface is supposed "
            @"to be collected.",
            numI);
    }
  }

  fprintf(stderr, "%s\n", err ? "FAIL" : "PASS");
  return err;
}
