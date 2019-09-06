// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef __GO_SEQ_HDR__
#define __GO_SEQ_HDR__

#include <Foundation/Foundation.h>

#ifdef DEBUG
#define LOG_DEBUG(...) NSLog(__VA_ARGS__);
#else
#define LOG_DEBUG(...) ;
#endif

#define LOG_INFO(...) NSLog(__VA_ARGS__);
#define LOG_FATAL(...)                                                         \
  {                                                                            \
    NSLog(__VA_ARGS__);                                                        \
    @throw                                                                     \
        [NSException exceptionWithName:NSInternalInconsistencyException        \
                                reason:[NSString stringWithFormat:__VA_ARGS__] \
                              userInfo:NULL];                                  \
  }

// GoSeqRef is an object tagged with an integer for passing back and
// forth across the language boundary. A GoSeqRef may represent either
// an instance of a Go object, or an Objective-C object passed to Go.
// The explicit allocation of a GoSeqRef is used to pin a Go object
// when it is passed to Objective-C. The Go seq package maintains a
// reference to the Go object in a map keyed by the refnum. When the
// GoSeqRef is deallocated, the Go seq package will clear the
// corresponding entry in the map.
// TODO(hyangah): update the doc as golang.org/issue/10933 is fixed.
@interface GoSeqRef : NSObject {
}
@property(readonly) int32_t refnum;
@property(strong) id obj; // NULL when representing a Go object.

// new GoSeqRef object to proxy a Go object. The refnum must be
// provided from Go side.
- (instancetype)initWithRefnum:(int32_t)refnum obj:(id)obj;

- (int32_t)incNum;

@end

@protocol goSeqRefInterface
-(GoSeqRef*) _ref;
@end

// Platform specific types
typedef struct nstring {
	void *ptr;
	int len;
} nstring;
typedef struct nbyteslice {
	void *ptr;
	int len;
} nbyteslice;
typedef int nint;

extern void init_seq();
// go_seq_dec_ref decrements the reference count for the
// specified refnum. It is called from Go from a finalizer.
extern void go_seq_dec_ref(int32_t refnum);
// go_seq_inc_ref increments the reference count for the
// specified refnum. It is called from Go just before converting
// a proxy to its refnum.
extern void go_seq_inc_ref(int32_t refnum);

extern int32_t go_seq_to_refnum(id obj);
// go_seq_go_to_refnum is a special case of go_seq_to_refnum
extern int32_t go_seq_go_to_refnum(GoSeqRef *ref);

extern GoSeqRef *go_seq_from_refnum(int32_t refnum);
// go_seq_objc_from_refnum is a special case of go_seq_from_refnum for
// Objective-C objects that implement a Go interface.
extern id go_seq_objc_from_refnum(int32_t refnum);

extern nbyteslice go_seq_from_objc_bytearray(NSData *data, int copy);
extern nstring go_seq_from_objc_string(NSString *s);

extern NSData *go_seq_to_objc_bytearray(nbyteslice, int copy);
extern NSString *go_seq_to_objc_string(nstring str);

#endif // __GO_SEQ_HDR__
