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
  NSString *got = GoTestpkg_Hello(input);
  NSString *want = [NSString stringWithFormat:@"Hello, %@!", input];
  if (!got) {
    ERROR(@"GoTestpkg_Hello(%@)= NULL, want %@", input, want);
    return;
  }
  if (![got isEqualToString:want]) {
    ERROR(@"want %@\nGoTestpkg_Hello(%@)= %@", want, input, got);
  }
}

void testBytesAppend(NSString *a, NSString *b) {
  NSData *data_a = [a dataUsingEncoding:NSUTF8StringEncoding];
  NSData *data_b = [b dataUsingEncoding:NSUTF8StringEncoding];
  NSData *gotData = GoTestpkg_BytesAppend(data_a, data_b);
  NSString *got =
      [[NSString alloc] initWithData:gotData encoding:NSUTF8StringEncoding];
  NSString *want = [a stringByAppendingString:b];
  if (![got isEqualToString:want]) {
    ERROR(@"want %@\nGoTestpkg_BytesAppend(%@, %@) = %@", want, a, b, got);
  }
}

// Invokes functions and object methods defined in Testpkg.h.
//
// TODO(hyangah): apply testing framework (e.g. XCTestCase)
// and test through xcodebuild.
int main(void) {
  @autoreleasepool {
    GoTestpkg_Hi();

    GoTestpkg_Int(42);

    int64_t sum = GoTestpkg_Sum(31, 21);
    if (sum != 52) {
      ERROR(@"GoTestpkg_Sum(31, 21) = %lld, want 52\n", sum);
    }

    testHello(@"세계"); // korean, utf-8, world.

    unichar t[] = {
        0xD83D, 0xDCA9,
    }; // utf-16, pile of poo.
    testHello([NSString stringWithCharacters:t length:2]);

    testBytesAppend(@"Foo", @"Bar");
  }

  fprintf(stderr, "%s\n", err ? "FAIL" : "PASS");
  return err;
}
