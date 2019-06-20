// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build ignore

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import "testpkg/Testpkg.h"

// Objective-C implementation of testpkg.I.
@interface Number : NSObject <GoTestpkgI2> {
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
   if ([s isEqualToString:@"number"]) {
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

// Objective-C implementation of testpkg.NullTest.
@interface NullTest : NSObject <GoTestpkgNullTest> {
}

- (GoTestpkgNullTest *)null;
@end

@implementation NullTest {
}

- (GoTestpkgNullTest *)null {
  return nil;
}
@end

// Objective-C implementation of testpkg.InterfaceDupper.
@interface IDup : NSObject <GoTestpkgInterfaceDupper> {
}

@end

@implementation IDup {
}

- (id<GoTestpkgInterface>)iDup:(id<GoTestpkgInterface>)i {
  return i;
}
@end

// Objective-C implementation of testpkg.ConcreteDupper.
@interface CDup : NSObject <GoTestpkgConcreteDupper> {
}

@end

@implementation CDup {
}

- (GoTestpkgConcrete *)cDup:(GoTestpkgConcrete *)c {
  return c;
}
@end

@interface tests : XCTestCase

@end

@implementation tests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testBasics {
    GoTestpkgHi();

    GoTestpkgInt(42);
}

- (void)testAdd {
    int64_t sum = GoTestpkgAdd(31, 21);
    XCTAssertEqual(sum, 52, @"GoTestpkgSum(31, 21) = %lld, want 52\n", sum);
}

- (void)testHello:(NSString *)input {
    NSString *got = GoTestpkgAppendHello(input);
    NSString *want = [NSString stringWithFormat:@"Hello, %@!", input];
    XCTAssertEqualObjects(got, want, @"want %@\nGoTestpkgHello(%@)= %@", want, input, got);
}

- (void)testHellos {
    [self testHello:@"세계"]; // korean, utf-8, world.
    unichar t[] = {
        0xD83D, 0xDCA9,
    }; // utf-16, pile of poo.
    [self testHello:[NSString stringWithCharacters:t length:2]];
}

- (void)testString {
    NSString *input = @"";
    NSString *got = GoTestpkgStrDup(input);
    XCTAssertEqualObjects(got, input, @"want %@\nGoTestpkgEcho(%@)= %@", input, input, got);

    input = @"FOO";
    got = GoTestpkgStrDup(input);
    XCTAssertEqualObjects(got, input, @"want %@\nGoTestpkgEcho(%@)= %@", input, input, got);
}

- (void)testStruct {
    GoTestpkgS2 *s = GoTestpkgNewS2(10.0, 100.0);
    XCTAssertNotNil(s, @"GoTestpkgNewS2 returned NULL");

    double x = [s x];
    double y = [s y];
    double sum = [s sum];
    XCTAssertTrue(x == 10.0 && y == 100.0 && sum == 110.0,
            @"GoTestpkgS2(10.0, 100.0).X=%f Y=%f SUM=%f; want 10, 100, 110", x, y, sum);

    double sum2 = GoTestpkgCallSSum(s);
    XCTAssertEqual(sum, sum2, @"GoTestpkgCallSSum(s)=%f; want %f as returned by s.Sum", sum2, sum);

    [s setX:7];
    [s setY:70];
    x = [s x];
    y = [s y];
    sum = [s sum];
    XCTAssertTrue(x == 7 && y == 70 && sum == 77,
            @"GoTestpkgS2(7, 70).X=%f Y=%f SUM=%f; want 7, 70, 77", x, y, sum);

    NSString *first = @"trytwotested";
    NSString *second = @"test";
    NSString *got = [s tryTwoStrings:first second:second];
    NSString *want = [first stringByAppendingString:second];
    XCTAssertEqualObjects(got, want, @"GoTestpkgS_TryTwoStrings(%@, %@)= %@; want %@", first, second, got, want);
}

- (void)testCollectS {
    @autoreleasepool {
        [self testStruct];
    }

    GoTestpkgGC();
    int numS = GoTestpkgCollectS2(
            1, 10); // within 10 seconds, collect the S used in testStruct.
    XCTAssertEqual(numS, 1, @"%d S objects were collected; S used in testStruct is supposed to "
                @"be collected.",
                numS);
}
- (void)testBytesAppend {
    NSString *a = @"Foo";
    NSString *b = @"Bar";
    NSData *data_a = [a dataUsingEncoding:NSUTF8StringEncoding];
    NSData *data_b = [b dataUsingEncoding:NSUTF8StringEncoding];
    NSData *gotData = GoTestpkgBytesAppend(data_a, data_b);
    NSString *got = [[NSString alloc] initWithData:gotData encoding:NSUTF8StringEncoding];
    NSString *want = [a stringByAppendingString:b];
    XCTAssertEqualObjects(got, want, @"want %@\nGoTestpkgBytesAppend(%@, %@) = %@", want, a, b, got);
}

- (void)testInterface {
    // Test Go object implementing testpkg.I is handled correctly.
    id<GoTestpkgI2> goObj = GoTestpkgNewI();
    int64_t got = [goObj times:10];
    XCTAssertEqual(got, 100, @"GoTestpkgNewI().times(10) = %lld; want %d", got, 100);
    int32_t key = -1;
    GoTestpkgRegisterI(key, goObj);
    int64_t got2 = GoTestpkgMultiply(key, 10);
    XCTAssertEqual(got, got2, @"GoTestpkgMultiply(10 * 10) = %lld; want %lld", got2, got);
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
        XCTAssertEqual(got, i * 2,@"GoTestpkgMultiply(%d, 2) = %lld; want %d", i, got, i * 2);
        GoTestpkgUnregisterI(i);
        GoTestpkgGC();
    }
    // Unregistered all Objective-C objects.
}

- (void)testCollectI {
    @autoreleasepool {
        [self testInterface];
    }
    XCTAssertEqual(numI, 1, @"%d I objects were collected; I used in testInterface is supposed "
                @"to be collected.", numI);
}

- (void)testConst {
	XCTAssertEqualObjects(GoTestpkgAString, @"a string", @"GoTestpkgAString = %@, want 'a string'", GoTestpkgAString);
	XCTAssertEqual(GoTestpkgAnInt, 7, @"GoTestpkgAnInt = %lld, want 7", GoTestpkgAnInt);
	XCTAssertTrue(ABS(GoTestpkgAFloat - 0.12345) < 0.0001, @"GoTestpkgAFloat = %f, want 0.12345", GoTestpkgAFloat);
	XCTAssertTrue(GoTestpkgABool == YES, @"GoTestpkgABool = %@, want YES", GoTestpkgAFloat ? @"YES" : @"NO");
	XCTAssertEqual(GoTestpkgMinInt32, INT32_MIN, @"GoTestpkgMinInt32 = %d, want %d", GoTestpkgMinInt32, INT32_MIN);
	XCTAssertEqual(GoTestpkgMaxInt32, INT32_MAX, @"GoTestpkgMaxInt32 = %d, want %d", GoTestpkgMaxInt32, INT32_MAX);
	XCTAssertEqual(GoTestpkgMinInt64, INT64_MIN, @"GoTestpkgMinInt64 = %lld, want %lld", GoTestpkgMinInt64, INT64_MIN);
	XCTAssertEqual(GoTestpkgMaxInt64, INT64_MAX, @"GoTestpkgMaxInt64 = %lld, want %lld", GoTestpkgMaxInt64, INT64_MAX);
	XCTAssertTrue(ABS(GoTestpkgSmallestNonzeroFloat64 -
          4.940656458412465441765687928682213723651e-324) < 1e-323, @"GoTestpkgSmallestNonzeroFloat64 = %f, want %f",
          GoTestpkgSmallestNonzeroFloat64,
          4.940656458412465441765687928682213723651e-324);
	XCTAssertTrue(ABS(GoTestpkgMaxFloat64 -
          1.797693134862315708145274237317043567981e+308) < 0.0001, @"GoTestpkgMaxFloat64 = %f, want %f", GoTestpkgMaxFloat64,
          1.797693134862315708145274237317043567981e+308);
	XCTAssertTrue(ABS(GoTestpkgSmallestNonzeroFloat32 -
          1.401298464324817070923729583289916131280e-45) < 1e-44, @"GoTestpkgSmallestNonzeroFloat32 = %f, want %f",
          GoTestpkgSmallestNonzeroFloat32,
          1.401298464324817070923729583289916131280e-45);
	XCTAssertTrue(ABS(GoTestpkgMaxFloat32 - 3.40282346638528859811704183484516925440e+38) < 0.0001,
		@"GoTestpkgMaxFloat32 = %f, want %f", GoTestpkgMaxFloat32, 3.40282346638528859811704183484516925440e+38);
	XCTAssertTrue(ABS(GoTestpkgLog2E - 1 / 0.693147180559945309417232121458176568075500134360255254120680009) < 0.0001,
		@"GoTestpkgLog2E = %f, want %f", GoTestpkgLog2E, 1 / 0.693147180559945309417232121458176568075500134360255254120680009);
}

- (void)testIssue12307 {
	Number *num = [[Number alloc] init];
	num.value = 1024;
	NSError *error;
	XCTAssertFalse(GoTestpkgCallIError(num, YES, &error), @"GoTestpkgCallIError(Number, YES) succeeded; want error");
	NSError *error2;
	XCTAssertTrue(GoTestpkgCallIError(num, NO, &error2), @"GoTestpkgCallIError(Number, NO) failed(%@); want success", error2);
}

- (void)testVar {
	NSString *s = GoTestpkg.stringVar;
	XCTAssertEqualObjects(s, @"a string var", @"GoTestpkg.StringVar = %@, want 'a string var'", s);
	s = @"a new string var";
	GoTestpkg.stringVar = s;
	NSString *s2 = GoTestpkg.stringVar;
	XCTAssertEqualObjects(s2, s, @"GoTestpkg.stringVar = %@, want %@", s2, s);

	int64_t i = GoTestpkg.intVar;
	XCTAssertEqual(i, 77, @"GoTestpkg.intVar = %lld, want 77", i);
	GoTestpkg.intVar = 777;
	i = GoTestpkg.intVar;
	XCTAssertEqual(i, 777, @"GoTestpkg.intVar = %lld, want 777", i);
	[GoTestpkg setIntVar:7777];
	i = [GoTestpkg intVar];
	XCTAssertEqual(i, 7777, @"GoTestpkg.intVar = %lld, want 7777", i);

	GoTestpkgNode *n0 = GoTestpkg.nodeVar;
	XCTAssertEqualObjects(n0.v, @"a struct var", @"GoTestpkg.NodeVar = %@, want 'a struct var'", n0.v);
	GoTestpkgNode *n1 = GoTestpkgNewNode(@"a new struct var");
	GoTestpkg.nodeVar = n1;
	GoTestpkgNode *n2 = GoTestpkg.nodeVar;
	XCTAssertEqualObjects(n2.v, @"a new struct var", @"GoTestpkg.NodeVar = %@, want 'a new struct var'", n2.v);

	Number *num = [[Number alloc] init];
	num.value = 12345;
	GoTestpkg.interfaceVar2 = num;
	id<GoTestpkgI2> iface = GoTestpkg.interfaceVar2;
	int64_t x = [iface times:10];
	int64_t y = [num times:10];
	XCTAssertEqual(x, y, @"GoTestpkg.InterfaceVar2 Times 10 = %lld, want %lld", x, y);
}

- (void)testIssue12403 {
	Number *num = [[Number alloc] init];
	num.value = 1024;

	NSString *ret;
	NSError *error;
	XCTAssertFalse(GoTestpkgCallIStringError(num, @"alphabet", &ret, &error), @"GoTestpkgCallIStringError(Number, 'alphabet') succeeded; want error");
	NSError *error2;
	XCTAssertTrue(GoTestpkgCallIStringError(num, @"number", &ret, &error2), @"GoTestpkgCallIStringError(Number, 'number') failed(%@); want success", error2);
	XCTAssertEqualObjects(ret, @"OK", @"GoTestpkgCallIStringError(Number, 'number') returned unexpected results %@", ret);
}

- (void)testStrDup:(NSString *)want {
	NSString *got = GoTestpkgStrDup(want);
	XCTAssertEqualObjects(want, got, @"StrDup returned %@; expected %@", got, want);
}

- (void)testUnicodeStrings {
	[self testStrDup:@"abcxyz09{}"];
	[self testStrDup:@"Hello, 世界"];
	[self testStrDup:@"\uffff\U00010000\U00010001\U00012345\U0010ffff"];
}

- (void)testByteArrayRead {
	NSData *arr = [NSMutableData dataWithLength:8];
	int n;
	XCTAssertTrue(GoTestpkgReadIntoByteArray(arr, &n, nil), @"ReadIntoByteArray failed");
	XCTAssertEqual(n, 8, @"ReadIntoByteArray wrote %d bytes, expected %d", n, 8);
	const uint8_t *b = [arr bytes];
	for (int i = 0; i < [arr length]; i++) {
		XCTAssertEqual(b[i], i, @"ReadIntoByteArray wrote %d at %d; expected %d", b[i], i, i);
	}
	// Test that immutable data cannot be changed from Go
	const uint8_t buf[] = {42};
	arr = [NSData dataWithBytes:buf length:1];
	XCTAssertTrue(GoTestpkgReadIntoByteArray(arr, &n, nil), @"ReadIntoByteArray failed");
	XCTAssertEqual(n, 1, @"ReadIntoByteArray wrote %d bytes, expected %d", n, 8);
	b = [arr bytes];
	XCTAssertEqual(b[0], 42, @"ReadIntoByteArray wrote to an immutable NSData; expected no change");
}

- (void)testNilField {
	GoTestpkgNullFieldStruct *s = GoTestpkgNewNullFieldStruct();
	XCTAssertNil([s f], @"NullFieldStruct has non-nil field; expected nil");
}

- (void)testNullReferences {
	NullTest *t = [[NullTest alloc] init];
	XCTAssertTrue(GoTestpkgCallWithNull(nil, t), @"GoTestpkg.CallWithNull failed");
	id<GoTestpkgI> i = GoTestpkgNewNullInterface();
	XCTAssertNil(i, @"NewNullInterface() returned %p; expected nil", i);
	GoTestpkgS *s = GoTestpkgNewNullStruct();
	XCTAssertNil(s, @"NewNullStruct() returned %p; expected nil", s);
}

- (void)testReturnsError {
	NSString *value;
	NSError *error;
	GoTestpkgReturnsError(TRUE, &value, &error);
	NSString *got = [error.userInfo valueForKey:NSLocalizedDescriptionKey];
	NSString *want = @"Error";
	XCTAssertEqualObjects(got, want, @"want %@\nGoTestpkgReturnsError(TRUE) = (%@, %@)", want, value, got);
}

- (void)testImportedPkg {
	XCTAssertEqualObjects(GoSecondpkgHelloString, GoSecondpkgHello(), @"imported string should match");
    id<GoSecondpkgI> i = GoTestpkgNewImportedI();
	GoSecondpkgS *s = GoTestpkgNewImportedS();
	XCTAssertEqual(8, [i f:8], @"numbers should match");
	XCTAssertEqual(8, [s f:8], @"numbers should match");
	i = GoTestpkgWithImportedI(i);
	s = GoTestpkgWithImportedS(s);
	i = [GoTestpkg importedVarI];
	s = [GoTestpkg importedVarS];
	[GoTestpkg setImportedVarI:i];
	[GoTestpkg setImportedVarS:s];
	GoTestpkgImportedFields *fields = GoTestpkgNewImportedFields();
	i = [fields i];
	s = [fields s];
	[fields setI:i];
	[fields setS:s];
}

- (void)testRoundTripEquality {
	Number *want = [[Number alloc] init];
	Number *got = (Number *)GoTestpkgI2Dup(want);
	XCTAssertEqual(got, want, @"ObjC object passed through Go should not be wrapped");

	IDup *idup = [[IDup alloc] init];
	XCTAssertTrue(GoTestpkgCallIDupper(idup), @"Go interface passed through ObjC should not be wrapped");
	CDup *cdup = [[CDup alloc] init];
	XCTAssertTrue(GoTestpkgCallCDupper(cdup), @"Go struct passed through ObjC should not be wrapped");
}

@end
