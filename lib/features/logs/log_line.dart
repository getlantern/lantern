import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/logs/parsed_log.dart';

class LogLineWidget extends StatefulWidget {
  final String line;

  const LogLineWidget({super.key, required this.line});

  @override
  State<LogLineWidget> createState() => _LogLineWidgetState();
}

class _LogLineWidgetState extends State<LogLineWidget> {
  late ParsedLog? _parsed;

  @override
  void initState() {
    super.initState();
    _parsed = parseLogLine(widget.line);
  }

  @override
  void didUpdateWidget(LogLineWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.line != widget.line) {
      _parsed = parseLogLine(widget.line);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parsed;

    if (parsed == null) {
      return Text(
        widget.line,
        style: AppTextStyles.monospace(color: context.textPrimary),
      );
    }

    final brightness = Theme.of(context).brightness;
    final levelColor = getLevelColor(parsed.level, brightness);
    final pkgColor = colorForId(parsed.pkg, brightness);

    return RichText(
      text: TextSpan(
        style: AppTextStyles.monospace(fontSize: 13),
        children: [
          TextSpan(
            text: parsed.level.toUpperCase(),
            style: TextStyle(color: levelColor, fontWeight: FontWeight.bold),
          ),
          const TextSpan(text: ' '),
          TextSpan(
            text: parsed.duration == null
                ? '[${parsed.pkg}] '
                : '[${parsed.pkg} ${parsed.duration}] ',
            style: TextStyle(color: pkgColor),
          ),
          TextSpan(
            text: parsed.message,
            style: TextStyle(color: context.textPrimary),
          ),
        ],
      ),
    );
  }
}
