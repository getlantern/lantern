import 'package:flutter/material.dart';
import 'package:lantern/features/logs/parsed_log.dart';

class LogLineWidget extends StatelessWidget {
  final String line;

  const LogLineWidget({super.key, required this.line});

  @override
  Widget build(BuildContext context) {
    final parsed = parseLogLine(line);

    if (parsed == null) {
      return Text(
        line,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'monospace',
        ),
      );
    }

    final levelColor = getLevelColor(parsed.level);
    final idColor = colorForId(parsed.id);

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
        ),
        children: [
          TextSpan(
            text: parsed.level.toUpperCase(),
            style: TextStyle(
              color: levelColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const TextSpan(text: ' '),
          TextSpan(
            text: '[${parsed.id} ${parsed.duration}] ',
            style: TextStyle(color: idColor),
          ),
          TextSpan(
            text: parsed.message,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
