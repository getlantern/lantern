// lib/providers/native_provider.dart

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lantern/core/services/native_bridge.dart';

final nativeBridgeProvider = Provider<NativeBridge?>((ref) {
  return Platform.isIOS ? NativeBridge() : null;
});
