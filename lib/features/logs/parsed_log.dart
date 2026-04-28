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

Color getLevelColor(String level, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  switch (level.toUpperCase()) {
    case 'DEBUG':
    case 'TRACE':
      return isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    case 'INFO':
      return isDark ? Colors.cyan.shade300 : Colors.cyan.shade700;
    case 'WARN':
    case 'WARNING':
      return isDark ? Colors.orange.shade300 : Colors.orange.shade800;
    case 'ERROR':
    case 'FATAL':
    case 'PANIC':
      return isDark ? Colors.redAccent.shade100 : Colors.red.shade700;
    default:
      return isDark ? Colors.white : Colors.black87;
  }
}

Color colorForId(String id, Brightness brightness) {
  final hash = int.tryParse(id) ?? id.hashCode;
  final colorIndex = hash % Colors.primaries.length;
  final swatch = Colors.primaries[colorIndex];
  return brightness == Brightness.dark ? swatch.shade300 : swatch.shade700;
}
