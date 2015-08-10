// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef __GO_SEQ_HDR__
#define __GO_SEQ_HDR__

#include <Foundation/Foundation.h>

// GoSeq is a sequence of machine-dependent encoded values, which
// is a simple C equivalent of seq.Buffer.
// Used by automatically generated language bindings to talk to Go.
typedef struct GoSeq {
  uint8_t *buf;
  size_t off;
  size_t len;
  size_t cap;
} GoSeq;

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
@property int32_t refnum;
@property(strong) id obj; // NULL when representing a Go object.

// new GoSeqRef object to proxy a Go object. The refnum must be
// provided from Go side.
- (instancetype)initWithRefnum:(int32_t)refnum obj:(id)obj;

@end

// go_seq_free releases resources of the GoSeq.
extern void go_seq_free(GoSeq *seq);

extern BOOL go_seq_readBool(GoSeq *seq);
extern int go_seq_readInt(GoSeq *seq);
extern int8_t go_seq_readInt8(GoSeq *seq);
extern int16_t go_seq_readInt16(GoSeq *seq);
extern int32_t go_seq_readInt32(GoSeq *seq);
extern int64_t go_seq_readInt64(GoSeq *seq);
extern float go_seq_readFloat32(GoSeq *seq);
extern double go_seq_readFloat64(GoSeq *seq);
extern GoSeqRef *go_seq_readRef(GoSeq *seq);
extern NSString *go_seq_readUTF8(GoSeq *seq);
extern NSData *go_seq_readByteArray(GoSeq *seq);

extern void go_seq_writeBool(GoSeq *seq, BOOL v);
extern void go_seq_writeInt(GoSeq *seq, int v);
extern void go_seq_writeInt8(GoSeq *seq, int8_t v);
extern void go_seq_writeInt16(GoSeq *seq, int16_t v);
extern void go_seq_writeInt32(GoSeq *seq, int32_t v);
extern void go_seq_writeInt64(GoSeq *seq, int64_t v);
extern void go_seq_writeFloat32(GoSeq *seq, float v);
extern void go_seq_writeFloat64(GoSeq *seq, double v);
extern void go_seq_writeRef(GoSeq *seq, GoSeqRef *ref);
extern void go_seq_writeUTF8(GoSeq *seq, NSString *v);

// go_seq_writeByteArray writes the data bytes to the seq. Note that the
// data should be valid until the the subsequent go_seq_send call completes.
extern void go_seq_writeByteArray(GoSeq *seq, NSData *data);

// go_seq_writeObjcRef is a special case of go_seq_writeRef for
// Objective-C objects that implement Go interface.
extern void go_seq_writeObjcRef(GoSeq *seq, id obj);

// go_seq_send sends a function invocation request to Go.
// It blocks until the function completes.
// If the request is for a method, the first element in req is
// a Ref to the receiver.
extern void go_seq_send(char *descriptor, int code, GoSeq *req, GoSeq *res);

extern void go_seq_register_proxy(const char *descriptor,
                           void(*fn)(id, int, GoSeq *, GoSeq *));

#endif // __GO_SEQ_HDR__
