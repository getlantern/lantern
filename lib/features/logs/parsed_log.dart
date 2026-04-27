import 'package:flutter/material.dart';

class ParsedLog {
  final String level;
  final String pkg;
  final String? duration;
  final String message;

  ParsedLog(this.level, this.pkg, this.duration, this.message);
}

final _logFieldRegex = RegExp(r'(\w+)=(".*?"|\S+)');

ParsedLog? parseLogLine(String line) {
  final fields = {
    for (final m in _logFieldRegex.allMatches(line))
      m.group(1)!: m.group(2)!.replaceAll('"', ''),
  };

  final level = fields['level'];
  final pkg = fields['pkg'];
  final msg = fields['msg'];

  if (level == null || pkg == null || msg == null) {
    return null;
  }

  return ParsedLog(level, pkg, fields['duration'], msg);
}

Color getLevelColor(String level) {
  switch (level.toUpperCase()) {
    case 'DEBUG':
    case 'TRACE':
      return Colors.grey.shade400;
    case 'INFO':
      return Colors.cyan;
    case 'WARN':
    case 'WARNING':
      return Colors.orange;
    case 'ERROR':
    case 'FATAL':
    case 'PANIC':
      return Colors.redAccent;
    default:
      return Colors.white;
  }
}

Color colorForId(String id) {
  final hash = int.tryParse(id) ?? id.hashCode;
  final colorIndex = hash % Colors.primaries.length;
  return Colors.primaries[colorIndex].shade300;
}
