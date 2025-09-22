import 'package:flutter/material.dart';

class ParsedLog {
  final String level;
  final String id;
  final String duration;
  final String message;

  ParsedLog(this.level, this.id, this.duration, this.message);
}

ParsedLog? parseLogLine(String line) {
  final regex = RegExp(r'(\w+)=(".*?"|\S+)');
  final fields = {
    for (final m in regex.allMatches(line))
      m.group(1)!: m.group(2)!.replaceAll('"', '')
  };

  final level = fields['level'];
  final service = fields['service'];
  final duration = fields['duration'];
  final msg = fields['msg'];

  if ([level, service, duration, msg].any((e) => e == null)) {
    return null;
  }

  return ParsedLog(level!, service!, duration!, msg!);
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
