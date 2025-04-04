import 'package:flutter/material.dart';

class ParsedLog {
  final String level;
  final String id;
  final String duration;
  final String message;

  ParsedLog(this.level, this.id, this.duration, this.message);
}

ParsedLog? parseLogLine(String line) {
  final levelMatch =
      RegExp(r'^(\w+)\[\d+\] \[(\d+)\s+([^\]]+)\] (.*)').firstMatch(line);
  if (levelMatch == null) return null;

  final level = levelMatch.group(1)!;
  final id = levelMatch.group(2)!;
  final duration = levelMatch.group(3)!;
  final message = levelMatch.group(4)!;

  return ParsedLog(level, id, duration, message);
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
