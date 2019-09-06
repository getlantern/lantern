// Copyright 2016 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <Foundation/Foundation.h>
#include "seq.h"
#include "_cgo_export.h"

//  * Objective-C implementation of a Go interface type
//
//  For an interface testpkg.I, gobind defines a protocol GoSeqTestpkgI.
//  Reference tracker (tracker) maintains two maps:
//     1) _refs: objective-C object pointer -> a refnum (starting from 42).
//     2) _objs: refnum -> RefCounter.
//
//  Whenever a user's object conforming the protocol is sent to Go (through
//  a function or method that takes I), _refs is consulted to find the refnum
//  of the object. If not found, the refnum is assigned and stored.
//
//  _objs is also updated so that the RefCounter is incremented and the
//  user's object is pinned.
//
//  When a Go side needs to call a method of the interface, the Go side
//  notifies the Objective-C side of the object's refnum. Upon receiving the
//  request, Objective-C side looks up the object from _objs map, and sends
//  the method to the object.
//
//  The RefCount counts the references on objective-C objects from Go side,
//  and pins the objective-C objects until there is no more references from
//  Go side.
//
//  * Objective-C proxy of a Go object (struct or interface type)
//
//  For Go type object, a objective-C proxy instance is created whenever
//  the object reference is passed into objective-C.
//
//  While crossing the language barrier there is a brief window where the foreign
//  proxy object might be finalized but the refnum is not yet translated to its object.
//  If the proxy object was the last reference to the foreign object, the refnum
//  will be invalid by the time it is looked up in the foreign reference tracker.
//
//  To make sure the foreign object is kept live while its refnum is in transit,
//  increment its refererence count before crossing. The other side will decrement
//  it again immediately after the refnum is converted to its object.

// Note that this file is copied into and compiled with the generated
// bindings.

// A simple thread-safe mutable dictionary.
@interface goSeqDictionary : NSObject {
}
@property NSMutableDictionary *dict;
@end

@implementation goSeqDictionary

- (id)init {
  if (self = [super init]) {
    _dict = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (id)get:(id)key {
  @synchronized(self) {
    return [_dict objectForKey:key];
  }
}

- (void)put:(id)obj withKey:(id)key {
  @synchronized(self) {
    [_dict setObject:obj forKey:key];
  }
}
@end

// NULL_REFNUM is also known to bind/seq/ref.go and bind/java/Seq.java
#define NULL_REFNUM 41

// RefTracker encapsulates a map of objective-C objects passed to Go and
// the reference number counter which is incremented whenever an objective-C
// object that implements a Go interface is created.
@interface RefTracker : NSObject {
  int32_t _next;
  NSMutableDictionary *_refs; // map: object ptr -> refnum
  NSMutableDictionary *_objs; // map: refnum -> RefCounter*
}

- (id)init;

// decrements the counter of the objective-C object with the reference number.
// This is called whenever a Go proxy to this object is finalized.
// When the counter reaches 0, the object is removed from the map.
- (void)dec:(int32_t)refnum;

// increments the counter of the objective-C object with the reference number.
// This is called whenever a Go proxy is converted to its refnum and send
// across the language barrier.
- (void)inc:(int32_t)refnum;

// returns the object of the reference number.
- (id)get:(int32_t)refnum;

// returns the reference number of the object and increments the ref count.
// This is called whenever an Objective-C object is sent to Go side.
- (int32_t)assignRefnumAndIncRefcount:(id)obj;
@end

static RefTracker *tracker = NULL;

#define IS_FROM_GO(refnum) ((refnum) < 0)

// init_seq is called when the Go side is initialized.
void init_seq() { tracker = [[RefTracker alloc] init]; }

void go_seq_dec_ref(int32_t refnum) {
  @autoreleasepool {
    [tracker dec:refnum];
  }
}

void go_seq_inc_ref(int32_t refnum) {
  @autoreleasepool {
    [tracker inc:refnum];
  }
}

NSData *go_seq_to_objc_bytearray(nbyteslice s, int copy) {
  if (s.ptr == NULL) {
    return NULL;
  }
  BOOL freeWhenDone = copy ? YES : NO;
  return [NSData dataWithBytesNoCopy:s.ptr length:s.len freeWhenDone:freeWhenDone];
}

NSString *go_seq_to_objc_string(nstring str) {
  if (str.len == 0) {  // empty string.
    return @"";
  }
  NSString * res = [[NSString alloc] initWithBytesNoCopy:str.ptr
                                                  length:str.len
                                                encoding:NSUTF8StringEncoding
                                            freeWhenDone:YES];
  return res;
}

id go_seq_objc_from_refnum(int32_t refnum) {
  id obj = [tracker get:refnum];
  // Go called IncForeignRef just before converting its proxy to its refnum. Decrement it here.
  // It's very important to decrement *after* fetching the reference from the tracker, in case
  // there are no other proxy references to the object.
  [tracker dec:refnum];
  return obj;
}

GoSeqRef *go_seq_from_refnum(int32_t refnum) {
  if (refnum == NULL_REFNUM) {
    return nil;
  }
  if (IS_FROM_GO(refnum)) {
    return [[GoSeqRef alloc] initWithRefnum:refnum obj:NULL];
  }
  return [[GoSeqRef alloc] initWithRefnum:refnum obj:go_seq_objc_from_refnum(refnum)];
}

int32_t go_seq_to_refnum(id obj) {
  if (obj == nil) {
    return NULL_REFNUM;
  }
  return [tracker assignRefnumAndIncRefcount:obj];
}

int32_t go_seq_go_to_refnum(GoSeqRef *ref) {
  int32_t refnum = [ref incNum];
  if (!IS_FROM_GO(refnum)) {
    LOG_FATAL(@"go_seq_go_to_refnum on objective-c objects is not permitted");
  }
  return refnum;
}

nbyteslice go_seq_from_objc_bytearray(NSData *data, int copy) {
  struct nbyteslice res = {NULL, 0};
  int sz = data.length;
  if (sz == 0) {
    return res;
  }
  void *ptr;
  // If the argument was not a NSMutableData, copy the data so that
  // the NSData is not changed from Go. The corresponding free is called
  // by releaseByteSlice.
  if (copy || ![data isKindOfClass:[NSMutableData class]]) {
    void *arr_copy = malloc(sz);
    if (arr_copy == NULL) {
      LOG_FATAL(@"malloc failed");
    }
    memcpy(arr_copy, [data bytes], sz);
    ptr = arr_copy;
  } else {
    ptr = (void *)[data bytes];
  }
  res.ptr = ptr;
  res.len = sz;
  return res;
}

nstring go_seq_from_objc_string(NSString *s) {
  nstring res = {NULL, 0};
  int len = [s lengthOfBytesUsingEncoding:NSUTF8StringEncoding];

  if (len == 0) {
    if (s.length > 0) {
      LOG_INFO(@"unable to encode an NSString into UTF-8");
    }
    return res;
  }

  char *buf = (char *)malloc(len);
  if (buf == NULL) {
    LOG_FATAL(@"malloc failed");
  }
  NSUInteger used;
  [s getBytes:buf
           maxLength:len
          usedLength:&used
            encoding:NSUTF8StringEncoding
             options:0
               range:NSMakeRange(0, [s length])
      remainingRange:NULL];
  res.ptr = buf;
  res.len = used;
  return res;
}

@implementation GoSeqRef {
}

- (id)init {
  LOG_FATAL(@"GoSeqRef init is disallowed");
}

- (int32_t)incNum {
  IncGoRef(_refnum);
  return _refnum;
}

// called when an object from Go is passed in.
- (instancetype)initWithRefnum:(int32_t)refnum obj:(id)obj {
  self = [super init];
  if (self) {
    _refnum = refnum;
    _obj = obj;
  }
  return self;
}

- (void)dealloc {
  if (IS_FROM_GO(_refnum)) {
    DestroyRef(_refnum);
  }
}
@end

// RefCounter is a pair of (GoSeqProxy, count). GoSeqProxy has a strong
// reference to an Objective-C object. The count corresponds to
// the number of Go proxy objects.
//
// RefTracker maintains a map of refnum to RefCounter, for every
// Objective-C objects passed to Go. This map allows the transact
// call to relay the method call to the right Objective-C object, and
// prevents the Objective-C objects from being deallocated
// while they are still referenced from Go side.
@interface RefCounter : NSObject {
}
@property(strong, readonly) id obj;
@property int cnt;

- (id)initWithObject:(id)obj;
@end

@implementation RefCounter {
}
- (id)initWithObject:(id)obj {
  self = [super init];
  if (self) {
    _obj = obj;
    _cnt = 0;
  }
  return self;
}

@end

@implementation RefTracker {
}

- (id)init {
  self = [super init];
  if (self) {
    _next = 42;
    _refs = [[NSMutableDictionary alloc] init];
    _objs = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (void)dec:(int32_t)refnum { // called whenever a go proxy object is finalized.
  if (IS_FROM_GO(refnum)) {
    LOG_FATAL(@"dec:invalid refnum for Objective-C objects");
  }
  @synchronized(self) {
    id key = @(refnum);
    RefCounter *counter = [_objs objectForKey:key];
    if (counter == NULL) {
      LOG_FATAL(@"unknown refnum");
    }
    int n = counter.cnt;
    if (n <= 0) {
      LOG_FATAL(@"refcount underflow");
    } else if (n == 1) {
      LOG_DEBUG(@"remove the reference %d", refnum);
      NSValue *ptr = [NSValue valueWithPointer:(const void *)(counter.obj)];
      [_refs removeObjectForKey:ptr];
      [_objs removeObjectForKey:key];
    } else {
      counter.cnt = n - 1;
    }
  }
}

// inc is called whenever a ObjC refnum crosses from Go to ObjC
- (void)inc:(int32_t)refnum {
  if (IS_FROM_GO(refnum)) {
    LOG_FATAL(@"dec:invalid refnum for Objective-C objects");
  }
  @synchronized(self) {
    id key = @(refnum);
    RefCounter *counter = [_objs objectForKey:key];
    if (counter == NULL) {
      LOG_FATAL(@"unknown refnum");
    }
    counter.cnt++;
  }
}

- (id)get:(int32_t)refnum {
  if (IS_FROM_GO(refnum)) {
    LOG_FATAL(@"get:invalid refnum for Objective-C objects");
  }
  @synchronized(self) {
    RefCounter *counter = _objs[@(refnum)];
    if (counter == NULL) {
      LOG_FATAL(@"unidentified object refnum: %d", refnum);
    }
    return counter.obj;
  }
}

- (int32_t)assignRefnumAndIncRefcount:(id)obj {
  @synchronized(self) {
    NSValue *ptr = [NSValue valueWithPointer:(const void *)(obj)];
    NSNumber *refnum = [_refs objectForKey:ptr];
    if (refnum == NULL) {
      refnum = @(_next++);
      _refs[ptr] = refnum;
    }
    RefCounter *counter = [_objs objectForKey:refnum];
    if (counter == NULL) {
      counter = [[RefCounter alloc] initWithObject:obj];
      counter.cnt = 1;
      _objs[refnum] = counter;
    } else {
      counter.cnt++;
    }
    return (int32_t)([refnum intValue]);
  }
}

@end
