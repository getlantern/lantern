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


// go_seq_free releases resources of the GoSeq.
extern void go_seq_free(GoSeq* seq);

extern int8_t go_seq_readInt8(GoSeq *seq);
extern int16_t go_seq_readInt16(GoSeq *seq);
extern int32_t go_seq_readInt32(GoSeq *seq);
extern int64_t go_seq_readInt64(GoSeq *seq);
extern float go_seq_readFloat32(GoSeq *seq);
extern double go_seq_readFloat64(GoSeq *seq);
extern NSString *go_seq_readUTF8(GoSeq *seq);
extern NSData *go_seq_readByteArray(GoSeq *seq);

extern void go_seq_writeInt8(GoSeq *seq, int8_t v);
extern void go_seq_writeInt16(GoSeq *seq, int16_t v);
extern void go_seq_writeInt32(GoSeq *seq, int32_t v);
extern void go_seq_writeInt64(GoSeq *seq, int64_t v);
extern void go_seq_writeFloat32(GoSeq *seq, float v);
extern void go_seq_writeFloat64(GoSeq *seq, double v);
extern void go_seq_writeUTF8(GoSeq *seq, NSString *v);

// go_seq_writeByteArray writes the data bytes to the seq. Note that the
// data should be valid until the the subsequent go_seq_send call completes.
extern void go_seq_writeByteArray(GoSeq *seq, NSData *data);

// go_seq_send sends a function invocation request to Go.
// It blocks until the function completes.
// If the request is for a method, the first element in req is
// a Ref to the receiver.
extern void go_seq_send(char *descriptor, int code, GoSeq *req, GoSeq *res);

#endif // __GO_SEQ_HDR__
