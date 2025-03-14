/*
 * Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
 * for details. All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

#ifndef RUNTIME_INCLUDE_ANALYZE_SNAPSHOT_API_H_
#define RUNTIME_INCLUDE_ANALYZE_SNAPSHOT_API_H_

#include <stdint.h>
#include <optional>

namespace dart {
namespace snapshot_analyzer {
typedef struct {
  const uint8_t* vm_snapshot_data;
  const uint8_t* vm_snapshot_instructions;
  const uint8_t* vm_isolate_data;
  const uint8_t* vm_isolate_instructions;
} Dart_SnapshotAnalyzerInformation;

void Dart_DumpSnapshotInformationAsJson(
    const Dart_SnapshotAnalyzerInformation& info,
    char** buffer,
    intptr_t* buffer_length);

}  // namespace snapshot_analyzer
}  // namespace dart

#endif  // RUNTIME_INCLUDE_ANALYZE_SNAPSHOT_API_H_
