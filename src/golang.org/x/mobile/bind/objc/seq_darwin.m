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
  {                                                                            \
    NSLog(__VA_ARGS__);                                                        \
    @throw                                                                     \
        [NSException exceptionWithName:NSInternalInconsistencyException        \
                                reason:[NSString stringWithFormat:__VA_ARGS__] \
                              userInfo:NULL];                                  \
  }

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
//  notifies the Objective-C side of the object's refnum, and the method code
//  as gobind assigned. Upon receiving the request, Objective-C side looks
//  up the object from _objs map, and looks up the proxy global function
//  registered in 'proxies'. The global function deserializes/serializes
//  the parameters and sends the method to the object.
//
//  The RefCount counts the references on objective-C objects from Go side,
//  and pins the objective-C objects until there is no more reference from
//  Go side.
//
//  * Objective-C proxy of a Go object (struct or interface type)
//
//  For Go type object, a objective-C proxy instance is created whenever
//  the object reference is passed into objective-C.

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

// The proxies maps Go interface name (e.g. go.testpkg.I) to the proxy function
// gobind generates for interfaces defined in a module. The function is
// registered by calling go_seq_register_proxy from a global contructor funcion.
static goSeqDictionary *proxies = NULL;

void go_seq_register_proxy(const char *descriptor,
                           void (*fn)(id, int, GoSeq *, GoSeq *)) {
  if (proxies == NULL) {
    proxies = [[goSeqDictionary alloc] init];
  }
  // Copying moves the block to the heap.
  id block = [^(id obj, int code, GoSeq *in, GoSeq *out) {
    fn(obj, code, in, out);
  } copy];

  [proxies put:block withKey:[NSString stringWithUTF8String:descriptor]];
}

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

// returns the object of the reference number.
- (id)get:(int32_t)refnum;

// returns the reference number of the object and increments the ref count.
// This is called whenever an Objective-C object is sent to Go side.
- (int32_t)assignRefnumAndIncRefcount:(id)obj;
@end

RefTracker *tracker = NULL;

// mem_ensure ensures that m has at least size bytes free.
// If m is NULL, it is created.
static void mem_ensure(GoSeq *m, uint32_t size) {
  size_t cap = m->cap;
  if (cap > m->off + size) {
    return;
  }
  if (cap == 0) {
    cap = 64;
  }
  while (cap < m->off + size) {
    cap *= 2;
  }
  m->buf = (uint8_t *)realloc((void *)m->buf, cap);
  if (m->buf == NULL) {
    LOG_FATAL(@"mem_ensure realloc failed, off=%zu, size=%u", m->off, size);
  }
  m->cap = cap;
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
  mem_ensure(m, offset - m->off + size);
  uint8_t *res = m->buf + offset;
  m->off = offset + size;
  m->len = offset + size;
  return res;
}

// extern
void go_seq_free(GoSeq *m) {
  if (m != NULL) {
    free(m->buf);
  }
}

#define MEM_READ(seq, ty) ((ty *)mem_read(seq, sizeof(ty), sizeof(ty)))
#define MEM_WRITE(seq, ty) (*(ty *)mem_write(seq, sizeof(ty), sizeof(ty)))

int go_seq_readInt(GoSeq *seq) {
  int64_t v = go_seq_readInt64(seq);
  return v; // Assume that Go-side used WriteInt to encode 'int' value.
}

void go_seq_writeInt(GoSeq *seq, int v) { go_seq_writeInt64(seq, v); }

BOOL go_seq_readBool(GoSeq *seq) {
  int8_t v = go_seq_readInt8(seq);
  return v ? YES : NO;
}

void go_seq_writeBool(GoSeq *seq, BOOL v) { go_seq_writeInt8(seq, v ? 1 : 0); }

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
  if (len == 0) {  // empty string.
    return @"";
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

  char *buf = (char *)mem_write(seq, len, 1);
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

  int64_t ptr = (int64_t)data.bytes;
  MEM_WRITE(seq, int64_t) = ptr;
  return;
}

typedef void (^proxyFn)(id, int, GoSeq *, GoSeq *);

// called from Go when Go tries to access an Objective-C object.
void go_seq_recv(int32_t refnum, const char *desc, int code, uint8_t *in_ptr,
                 size_t in_len, uint8_t **out_ptr, size_t *out_len) {
  if (code == -1) { // special signal from seq.FinalizeRef in Go
    [tracker dec:refnum];
    return;
  }
  GoSeq ins = {};
  ins.buf = in_ptr; // Memory allocated from Go
  ins.off = 0;
  ins.len = in_len;
  ins.cap = in_len;
  id obj = [tracker get:refnum];
  if (obj == NULL) {
    LOG_FATAL(@"invalid object for ref %d", refnum);
    return;
  }

  NSString *k = [NSString stringWithUTF8String:desc];

  proxyFn fn = NULL;
  if (proxies != NULL) {
    fn = [proxies get:k];
  }
  if (fn == NULL) {
    LOG_FATAL(@"cannot find a proxy function for %s", desc);
    return;
  }
  GoSeq outs = {};
  fn(obj, code, &ins, &outs);

  if (out_ptr == NULL) {
    free(outs.buf);
  } else {
    *out_ptr = outs.buf; // Let Go side free this memory
    *out_len = outs.len;
  }
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
  if (res != NULL) {
    res_buf = &res->buf;
    res_len = &res->len;
  }

  GoString desc;
  desc.p = descriptor;
  desc.n = strlen(descriptor);
  Send(desc, (GoInt)code, req_buf, req_len, res_buf, res_len);
}

#define IS_FROM_GO(refnum) ((refnum) < 0)

// init_seq is called when the Go side is initialized.
void init_seq() { tracker = [[RefTracker alloc] init]; }

GoSeqRef *go_seq_readRef(GoSeq *seq) {
  int32_t refnum = go_seq_readInt32(seq);
  if (IS_FROM_GO(refnum)) {
    return [[GoSeqRef alloc] initWithRefnum:refnum obj:NULL];
  }
  return [[GoSeqRef alloc] initWithRefnum:refnum obj:[tracker get:refnum]];
}

// TODO(hyangah): make this go_seq_writeRef(GoSeq *seq, int32_t refnum, id obj)
// and get read of GoSeqRef.
void go_seq_writeRef(GoSeq *seq, GoSeqRef *v) {
  int32_t refnum = v.refnum;
  if (!IS_FROM_GO(refnum)) {
    LOG_FATAL(@"go_seq_writeRef on objective-c objects is not permitted");
  }
  go_seq_writeInt32(seq, refnum);
  return;
}

void go_seq_writeObjcRef(GoSeq *seq, id obj) {
  int32_t refnum = [tracker assignRefnumAndIncRefcount:obj];
  go_seq_writeInt32(seq, refnum);
}

@implementation GoSeqRef {
}

- (id)init {
  LOG_FATAL(@"GoSeqRef init is disallowed");
  return nil;
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
    _objs = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (void)dec:(int32_t)refnum { // called whenever a go proxy object is finalized.
  if (IS_FROM_GO(refnum)) {
    LOG_FATAL(@"dec:invalid refnum for Objective-C objects");
    return;
  }
  @synchronized(self) {
    id key = @(refnum);
    RefCounter *counter = [_objs objectForKey:key];
    if (counter == NULL) {
      LOG_FATAL(@"unknown refnum");
      return;
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

- (id)get:(int32_t)refnum {
  if (IS_FROM_GO(refnum)) {
    LOG_FATAL(@"get:invalid refnum for Objective-C objects");
    return NULL;
  }
  @synchronized(self) {
    RefCounter *counter = _objs[@(refnum)];
    if (counter == NULL) {
      LOG_FATAL(@"unidentified object refnum: %d", refnum);
      return NULL;
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
