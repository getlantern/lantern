// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef SENSORS_ANDROID_H
#define SENSORS_ANDROID_H

typedef struct android_SensorManager {
  ASensorEventQueue* queue;
  ALooper* looper;
  int looperId;
} android_SensorManager;

void android_createManager(int looperId, android_SensorManager* dst);
void android_destroyManager(android_SensorManager* m);
int  android_enableSensor(ASensorEventQueue*, int, int32_t);
void android_disableSensor(ASensorEventQueue*, int);
int  android_readQueue(int looperId, ASensorEventQueue* q, int n, int32_t* types, int64_t* timestamps, float* vectors);

#endif
