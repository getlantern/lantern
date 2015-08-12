// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <stdlib.h>
#include <jni.h>

#include <android/sensor.h>

#include "sensors_android.h"

void android_createManager(int looperId, android_SensorManager* dst) {
  ASensorManager* manager = ASensorManager_getInstance();

  ALooper* looper = ALooper_forThread();
  if (looper == NULL) {
    looper = ALooper_prepare(ALOOPER_PREPARE_ALLOW_NON_CALLBACKS);
  }
  ASensorEventQueue* queue = ASensorManager_createEventQueue(manager, looper, looperId, NULL, NULL);
  dst->looper = looper;
  dst->queue = queue;
  dst->looperId = looperId;
}

int android_enableSensor(ASensorEventQueue* q, int s, int32_t usec) {
  ASensorManager* manager = ASensorManager_getInstance();
  const ASensor* sensor = ASensorManager_getDefaultSensor(manager, s);
  if (sensor == NULL) {
    return 1;
  }
  ASensorEventQueue_enableSensor(q, sensor);
  ASensorEventQueue_setEventRate(q, sensor, usec);
  return 0;
}

void android_disableSensor(ASensorEventQueue* q, int s) {
  ASensorManager* manager = ASensorManager_getInstance();
  const ASensor* sensor = ASensorManager_getDefaultSensor(manager, s);
  ASensorEventQueue_disableSensor(q, sensor);
}

int android_readQueue(int looperId, ASensorEventQueue* q, int n, int32_t* types, int64_t* timestamps, float* vectors) {
  int id;
  int events;
  ASensorEvent event;
  int i = 0;
  // Block for 30 secs at most, timeout if nothing happens.
  // Try n times read from the event queue.
  // If anytime timeout occurs, don't retry to read and immediately return.
  // Consume the event queue entirely between polls.
  while (i < n && (id = ALooper_pollAll(30*1000, NULL, &events, NULL)) >= 0) {
    if (id != looperId) {
      continue;
    }
    while (i < n && ASensorEventQueue_getEvents(q, &event, 1)) {
      types[i] = event.type;
      timestamps[i] = event.timestamp;
      vectors[i*3] = event.vector.x;
      vectors[i*3+1] = event.vector.y;
      vectors[i*3+2] = event.vector.z;
      i++;
    }
  }
  return i;
}

void android_destroyManager(android_SensorManager* m) {
  ASensorManager* manager = ASensorManager_getInstance();
  ASensorManager_destroyEventQueue(manager, m->queue);
  ALooper_release(m->looper);
}
