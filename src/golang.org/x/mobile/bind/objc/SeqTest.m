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

void testConst() {
  if (![GoTestpkgAString isEqualToString:@"a string"]) {
    ERROR(@"GoTestpkgAString = %@, want 'a string'", GoTestpkgAString);
  }
  if (GoTestpkgAnInt != 7) {
    ERROR(@"GoTestpkgAnInt = %lld, want 7", GoTestpkgAnInt);
  }
  if (ABS(GoTestpkgAFloat - 0.12345) > 0.0001) {
    ERROR(@"GoTestpkgAFloat = %f, want 0.12345", GoTestpkgAFloat);
  }
  if (GoTestpkgABool != YES) {
    ERROR(@"GoTestpkgABool = %@, want YES", GoTestpkgAFloat ? @"YES" : @"NO");
  }

  if (GoTestpkgMinInt32 != INT32_MIN) {
    ERROR(@"GoTestpkgMinInt32 = %d, want %d", GoTestpkgMinInt32, INT32_MIN);
  }
  if (GoTestpkgMaxInt32 != INT32_MAX) {
    ERROR(@"GoTestpkgMaxInt32 = %d, want %d", GoTestpkgMaxInt32, INT32_MAX);
  }
  if (GoTestpkgMinInt64 != INT64_MIN) {
    ERROR(@"GoTestpkgMinInt64 = %lld, want %lld", GoTestpkgMinInt64, INT64_MIN);
  }
  if (GoTestpkgMaxInt64 != INT64_MAX) {
    ERROR(@"GoTestpkgMaxInt64 = %lld, want %lld", GoTestpkgMaxInt64, INT64_MAX);
  }
  if (ABS(GoTestpkgSmallestNonzeroFloat64 -
          4.940656458412465441765687928682213723651e-324) > 1e-323) {
    ERROR(@"GoTestpkgSmallestNonzeroFloat64 = %f, want %f",
          GoTestpkgSmallestNonzeroFloat64,
          4.940656458412465441765687928682213723651e-324);
  }
  if (ABS(GoTestpkgMaxFloat64 -
          1.797693134862315708145274237317043567981e+308) > 0.0001) {
    ERROR(@"GoTestpkgMaxFloat64 = %f, want %f", GoTestpkgMaxFloat64,
          1.797693134862315708145274237317043567981e+308);
  }
  if (ABS(GoTestpkgSmallestNonzeroFloat32 -
          1.401298464324817070923729583289916131280e-45) > 1e-44) {
    ERROR(@"GoTestpkgSmallestNonzeroFloat32 = %f, want %f",
          GoTestpkgSmallestNonzeroFloat32,
          1.401298464324817070923729583289916131280e-45);
  }
  if (ABS(GoTestpkgMaxFloat32 - 3.40282346638528859811704183484516925440e+38) >
      0.0001) {
    ERROR(@"GoTestpkgMaxFloat32 = %f, want %f", GoTestpkgMaxFloat32,
          3.40282346638528859811704183484516925440e+38);
  }
  if (ABS(GoTestpkgLog2E -
          1 / 0.693147180559945309417232121458176568075500134360255254120680009) >
      0.0001) {
    ERROR(
        @"GoTestpkgLog2E = %f, want %f", GoTestpkgLog2E,
        1 / 0.693147180559945309417232121458176568075500134360255254120680009);
  }
}

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

void testString() {
  NSString *input = @"";
  NSString *got = GoTestpkgEcho(input);
  if (!got || ![got isEqualToString:input]) {
    ERROR(@"want %@\nGoTestpkgEcho(%@)= %@", input, input, got);
  }

  input = @"FOO";
  got = GoTestpkgEcho(input);
  if (!got || ![got isEqualToString:input]) {
    ERROR(@"want %@\nGoTestpkgEcho(%@)= %@", input, input, got);
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

  double x = [s x];
  double y = [s y];
  double sum = [s sum];
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
  x = [s x];
  y = [s y];
  sum = [s sum];
  if (x != 7 || y != 70 || sum != 77) {
    ERROR(@"GoTestpkgS(7, 70).X=%f Y=%f SUM=%f; want 7, 70, 77", x, y, sum);
  }

  NSString *first = @"trytwotested";
  NSString *second = @"test";
  NSString *got = [s tryTwoStrings:first second:second];
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

// TODO(hyangah): error:error is not good.
- (BOOL)error:(BOOL)e error:(NSError **)error;
- (int64_t)times:(int32_t)v;
@end

// numI is incremented when the first numI objective-C implementation is
// deallocated.
static int numI = 0;

@implementation Number {
}
@synthesize value;

- (BOOL)stringError:(NSString *)s
              ret0_:(NSString **)ret0_
              error:(NSError **)error {
  if ([s isEqualTo:@"number"]) {
    if (ret0_ != NULL) {
      *ret0_ = @"OK";
    }
    return true;
  }
  return false;
}

- (BOOL)error:(BOOL)triggerError error:(NSError **)error {
  if (!triggerError) {
    return YES;
  }
  if (error != NULL) {
    *error = [NSError errorWithDomain:@"SeqTest" code:1 userInfo:NULL];
  }
  return NO;
}

- (int64_t)times:(int32_t)v {
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
  int64_t got = [goObj times:10];
  if (got != 100) {
    ERROR(@"GoTestpkgNewI().times(10) = %lld; want %d", got, 100);
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

void testIssue12307() {
  Number *num = [[Number alloc] init];
  num.value = 1024;
  NSError *error;
  if (GoTestpkgCallIError(num, YES, &error) == YES) {
    ERROR(@"GoTestpkgCallIError(Number, YES) succeeded; want error");
  }
  NSError *error2;
  if (GoTestpkgCallIError(num, NO, &error2) == NO) {
    ERROR(@"GoTestpkgCallIError(Number, NO) failed(%@); want success", error2);
  }
}

void testIssue12403() {
  Number *num = [[Number alloc] init];
  num.value = 1024;

  NSString *ret;
  NSError *error;
  if (GoTestpkgCallIStringError(num, @"alphabet", &ret, &error) == YES) {
    ERROR(
        @"GoTestpkgCallIStringError(Number, 'alphabet') succeeded; want error");
  }
  NSError *error2;
  if (GoTestpkgCallIStringError(num, @"number", &ret, &error2) == NO) {
    ERROR(
        @"GoTestpkgCallIStringError(Number, 'number') failed(%@); want success",
        error2);
  } else if (![ret isEqualTo:@"OK"]) {
    ERROR(@"GoTestpkgCallIStringError(Number, 'number') returned unexpected "
          @"results %@",
          ret);
  }
}

void testVar() {
  NSString *s = GoTestpkg.stringVar;
  if (![s isEqualToString:@"a string var"]) {
    ERROR(@"GoTestpkg.StringVar = %@, want 'a string var'", s);
  }
  s = @"a new string var";
  GoTestpkg.stringVar = s;
  NSString *s2 = GoTestpkg.stringVar;
  if (![s2 isEqualToString:s]) {
    ERROR(@"GoTestpkg.stringVar = %@, want %@", s2, s);
  }

  int64_t i = GoTestpkg.intVar;
  if (i != 77) {
    ERROR(@"GoTestpkg.intVar = %lld, want 77", i);
  }
  GoTestpkg.intVar = 777;
  i = GoTestpkg.intVar;
  if (i != 777) {
    ERROR(@"GoTestpkg.intVar = %lld, want 777", i);
  }
  [GoTestpkg setIntVar:7777];
  i = [GoTestpkg intVar];
  if (i != 7777) {
    ERROR(@"GoTestpkg.intVar = %lld, want 7777", i);
  }

  GoTestpkgNode *n0 = GoTestpkg.structVar;
  if (![n0.v isEqualToString:@"a struct var"]) {
    ERROR(@"GoTestpkg.structVar = %@, want 'a struct var'", n0.v);
  }
  GoTestpkgNode *n1 = GoTestpkgNewNode(@"a new struct var");
  GoTestpkg.structVar = n1;
  GoTestpkgNode *n2 = GoTestpkg.structVar;
  if (![n2.v isEqualToString:@"a new struct var"]) {
    ERROR(@"GoTestpkg.StructVar = %@, want 'a new struct var'", n2.v);
  }

  Number *num = [[Number alloc] init];
  num.value = 12345;
  GoTestpkg.interfaceVar = num;
  id<GoTestpkgI> iface = GoTestpkg.interfaceVar;
  int64_t x = [iface times:10];
  int64_t y = [num times:10];
  if (x != y) {
    ERROR(@"GoTestpkg.InterfaceVar Times 10 = %lld, want %lld", x, y);
  }
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

    testString();

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

    testConst();

    testIssue12307();

    testVar();
  }

  fprintf(stderr, "%s\n", err ? "FAIL" : "PASS");
  return err;
}
