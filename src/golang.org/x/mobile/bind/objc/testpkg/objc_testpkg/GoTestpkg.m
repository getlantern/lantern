
// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Output of gobind -lang=objc

#include "GoTestpkg.h"
#include <Foundation/Foundation.h>
#include "seq.h"

#define _DESCRIPTOR_ "testpkg"

#define _CALL_BytesAppend_ 1
#define _CALL_Hello_ 2
#define _CALL_Hi_ 3
#define _CALL_Int_ 4
#define _CALL_Sum_ 5

NSData *GoTestpkg_BytesAppend(NSData *a, NSData *b) {
  GoSeq in = {};
  GoSeq out = {};
  go_seq_writeByteArray(&in, a);
  go_seq_writeByteArray(&in, b);
  go_seq_send(_DESCRIPTOR_, _CALL_BytesAppend_, &in, &out);

  NSData *ret = go_seq_readByteArray(&out);
  go_seq_free(&out);
  go_seq_free(&in);
  return ret;
}

void GoTestpkg_Hi() {
  // No input, output.
  GoSeq in = {};
  GoSeq out = {};
  go_seq_send(_DESCRIPTOR_, _CALL_Hi_, &in, &out);
  go_seq_free(&out);
  go_seq_free(&in);
}

void GoTestpkg_Int(int32_t x) {
  GoSeq in = {};
  GoSeq out = {};
  go_seq_writeInt32(&in, x);
  go_seq_send(_DESCRIPTOR_, _CALL_Int_, &in, &out);
  go_seq_free(&out);
  go_seq_free(&in);
}

int64_t GoTestpkg_Sum(int64_t x, int64_t y) {
  GoSeq in = {};
  GoSeq out = {};
  go_seq_writeInt64(&in, x);
  go_seq_writeInt64(&in, y);
  go_seq_send(_DESCRIPTOR_, _CALL_Sum_, &in, &out);
  int64_t res = go_seq_readInt64(&out);
  go_seq_free(&out);
  go_seq_free(&in);
  return res;
}

NSString *GoTestpkg_Hello(NSString *s) {
  GoSeq in = {};
  GoSeq out = {};
  go_seq_writeUTF8(&in, s);
  go_seq_send(_DESCRIPTOR_, _CALL_Hello_, &in, &out);
  NSString *res = go_seq_readUTF8(&out);
  go_seq_free(&out);
  go_seq_free(&in);
  return res;
}
