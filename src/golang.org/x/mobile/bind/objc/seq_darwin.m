// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <Foundation/Foundation.h>
#include "seq.h"
#include "_cgo_export.h"

#ifdef DEBUG
#define LOG_DEBUG(...) NSLog(__VA_ARGS__);
#else
#define LOG_DEBUG(...) ;
#endif

#define LOG_INFO(...) NSLog(__VA_ARGS__);
#define LOG_FATAL(...)                                                         \
  @throw                                                                       \
      [NSException exceptionWithName:NSInternalInconsistencyException          \
                              reason:[NSString stringWithFormat:__VA_ARGS__]   \
                            userInfo:NULL];

// mem_ensure ensures that m has at least size bytes free.
// If m is NULL, it is created.
static void mem_ensure(GoSeq *m, uint32_t size) {
  if (m->cap > m->off + size) {
    return;
  }
  m->buf = (uint8_t *)realloc((void *)m->buf, m->off + size);
  if (m->buf == NULL) {
    LOG_FATAL(@"mem_ensure realloc failed, off=%zu, size=%u", m->off, size);
  }
  m->cap = m->off + size;
}

static uint32_t align(uint32_t offset, uint32_t alignment) {
  uint32_t pad = offset % alignment;
  if (pad > 0) {
    pad = alignment - pad;
  }
  return pad + offset;
}

static uint8_t *mem_read(GoSeq *m, uint32_t size, uint32_t alignment) {
  if (size == 0) {
    return NULL;
  }
  if (m == NULL) {
    LOG_FATAL(@"mem_read on NULL GoSeq");
  }
  uint32_t offset = align(m->off, alignment);

  if (m->len - offset < size) {
    LOG_FATAL(@"short read");
  }
  uint8_t *res = m->buf + offset;
  m->off = offset + size;
  return res;
}

static uint8_t *mem_write(GoSeq *m, uint32_t size, uint32_t alignment) {
  if (m->off != m->len) {
    LOG_FATAL(@"write can only append to seq, size: (off=%zu len=%zu, size=%u)",
              m->off, m->len, size);
  }
  uint32_t offset = align(m->off, alignment);
  uint32_t cap = m->cap;
  if (cap == 0) { cap = 64; }
  while (offset + size > cap) {
    cap *= 2;
  }
  mem_ensure(m, cap);
  uint8_t *res = m->buf + offset;
  m->off = offset + size;
  m->len = offset + size;
  return res;
}

// extern
void go_seq_free(GoSeq* m) {
  if (m != NULL) {
    free(m->buf);
  }
}

#define MEM_READ(seq, ty) ((ty *)mem_read(seq, sizeof(ty), sizeof(ty)))
#define MEM_WRITE(seq, ty) (*(ty *)mem_write(seq, sizeof(ty), sizeof(ty)))

int8_t go_seq_readInt8(GoSeq *seq) {
  int8_t *v = MEM_READ(seq, int8_t);
  return v == NULL ? 0 : *v;
}
void go_seq_writeInt8(GoSeq *seq, int8_t v) { MEM_WRITE(seq, int8_t) = v; }

int16_t go_seq_readInt16(GoSeq *seq) {
  int16_t *v = MEM_READ(seq, int16_t);
  return v == NULL ? 0 : *v;
}
void go_seq_writeInt16(GoSeq *seq, int16_t v) { MEM_WRITE(seq, int16_t) = v; }

int32_t go_seq_readInt32(GoSeq *seq) {
  int32_t *v = MEM_READ(seq, int32_t);
  return v == NULL ? 0 : *v;
}
void go_seq_writeInt32(GoSeq *seq, int32_t v) { MEM_WRITE(seq, int32_t) = v; }

int64_t go_seq_readInt64(GoSeq *seq) {
  int64_t *v = MEM_READ(seq, int64_t);
  return v == NULL ? 0 : *v;
}
void go_seq_writeInt64(GoSeq *seq, int64_t v) { MEM_WRITE(seq, int64_t) = v; }

float go_seq_readFloat32(GoSeq *seq) {
  float *v = MEM_READ(seq, float);
  return v == NULL ? 0 : *v;
}
void go_seq_writeFloat32(GoSeq *seq, float v) { MEM_WRITE(seq, float) = v; }

double go_seq_readFloat64(GoSeq *seq) {
  double *v = MEM_READ(seq, double);
  return v == NULL ? 0 : *v;
}
void go_seq_writeFloat64(GoSeq *seq, double v) { MEM_WRITE(seq, double) = v; }

NSString *go_seq_readUTF8(GoSeq *seq) {
  int32_t len = *MEM_READ(seq, int32_t);
  if (len == 0) {
    return NULL;
  }
  const void *buf = (const void *)mem_read(seq, len, 1);
  return [[NSString alloc] initWithBytes:buf
                                  length:len
                                encoding:NSUTF8StringEncoding];
}

void go_seq_writeUTF8(GoSeq *seq, NSString *s) {
  int32_t len = [s lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
  MEM_WRITE(seq, int32_t) = len;

  if (len == 0 && s.length > 0) {
    LOG_INFO(@"unable to incode an NSString into UTF-8");
    return;
  }

  char *buf = (char *)mem_write(seq, len + 1, 1);
  NSUInteger used;
  [s getBytes:buf
           maxLength:len
          usedLength:&used
            encoding:NSUTF8StringEncoding
             options:0
               range:NSMakeRange(0, [s length])
      remainingRange:NULL];
  if (used < len) {
    buf[used] = '\0';
  }
  return;
}

NSData *go_seq_readByteArray(GoSeq *seq) {
  int64_t sz = *MEM_READ(seq, int64_t);
  if (sz == 0) {
    return [NSData data];
  }
  // BUG(hyangah): it is possible that *ptr is already GC'd by Go runtime.
  void *ptr = (void *)(*MEM_READ(seq, int64_t));
  return [NSData dataWithBytes:ptr length:sz];
}

void go_seq_writeByteArray(GoSeq *seq, NSData *data) {
  int64_t sz = data.length;
  MEM_WRITE(seq, int64_t) = sz;
  if (sz == 0) {
    return;
  }

  int64_t ptr = data.bytes;
  MEM_WRITE(seq, int64_t) = ptr;
  return;
}

void go_seq_send(char *descriptor, int code, GoSeq *req, GoSeq *res) {
  if (descriptor == NULL) {
    LOG_FATAL(@"invalid NULL descriptor");
  }
  uint8_t *req_buf = NULL;
  size_t req_len = 0;
  if (req != NULL) {
    req_buf = req->buf;
    req_len = req->len;
  }

  uint8_t **res_buf = NULL;
  size_t *res_len = NULL;
  if (res == NULL) {
    mem_ensure(res, 64);
  }
  res_buf = &res->buf;
  res_len = &res->len;

  GoString desc;
  desc.p = descriptor;
  desc.n = strlen(descriptor);
  Send(desc, (GoInt)code, req_buf, req_len, res_buf, res_len);
}
