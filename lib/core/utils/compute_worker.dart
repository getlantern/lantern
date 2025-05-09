import 'dart:async';

import 'package:flutter/foundation.dart';

Future<T> runInBackground<T>(Future<T> Function() computation) async {
  final result = await compute(_compute, computation);
  return result;
}

// Helper function that runs the computation in an isolate
Future<T> _compute<T>(Future<T> Function() computation) async {
  return await computation();
}
