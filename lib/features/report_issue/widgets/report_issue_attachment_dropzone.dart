import 'dart:async';
import 'dart:math' as math;

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';

class ReportIssueAttachmentDropzone extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final Future<void> Function(List<XFile> files)? onDrop;
  final bool enableDesktopDrop;
  final bool enabled;

  const ReportIssueAttachmentDropzone({
    super.key,
    required this.label,
    required this.onTap,
    this.onDrop,
    this.enableDesktopDrop = false,
    this.enabled = true,
  });

  @override
  State<ReportIssueAttachmentDropzone> createState() =>
      _ReportIssueAttachmentDropzoneState();
}

class _ReportIssueAttachmentDropzoneState
    extends State<ReportIssueAttachmentDropzone> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.enabled;
    final child = Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('report_issue.attachments.add_button'),
          borderRadius: defaultBorderRadius,
          onTap: isEnabled ? widget.onTap : null,
          child: CustomPaint(
            painter: _DashedBorderPainter(
              color: _borderColor(context, isEnabled),
              strokeWidth: 1.5,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              decoration: BoxDecoration(
                color: _backgroundColor(context, isEnabled),
                borderRadius: defaultBorderRadius,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    color: isEnabled
                        ? context.textPrimary
                        : context.textDisabled,
                    size: 28,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isEnabled
                          ? context.textPrimary
                          : context.textDisabled,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (!widget.enableDesktopDrop || widget.onDrop == null) {
      return child;
    }

    return DropTarget(
      enable: isEnabled,
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) {
        setState(() => _isDragging = false);
        unawaited(widget.onDrop!(details.files));
      },
      child: child,
    );
  }

  Color _backgroundColor(BuildContext context, bool isEnabled) {
    if (!isEnabled) {
      return context.bgCallout.withValues(alpha: 0.55);
    }
    if (_isDragging) {
      return context.bgHover;
    }
    return context.bgCallout.withValues(alpha: 0.55);
  }

  Color _borderColor(BuildContext context, bool isEnabled) {
    if (!isEnabled) {
      return context.borderDefault;
    }
    if (_isDragging) {
      return context.borderInputFocus;
    }
    return context.borderInput;
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const _DashedBorderPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + 8, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + 6;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}
