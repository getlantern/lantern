import 'package:flutter_riverpod/flutter_riverpod.dart';

final diagnosticLogProvider = StreamProvider<List<String>>((ref) async* {
  final logs = <String>[];
  yield logs;
});
