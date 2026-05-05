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
  final bool compact;

  const ReportIssueAttachmentDropzone({
    super.key,
    required this.label,
    required this.onTap,
    this.onDrop,
    this.enableDesktopDrop = false,
    this.enabled = true,
    this.compact = false,
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
      enabled: isEnabled,
      label: widget.label,
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
              borderRadius: defaultBorderRadius,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              constraints: BoxConstraints(minHeight: widget.compact ? 56 : 112),
              padding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: widget.compact ? 14 : 22,
              ),
              decoration: BoxDecoration(
                color: _backgroundColor(context, isEnabled),
                borderRadius: defaultBorderRadius,
              ),
              child: widget.compact
                  ? _CompactDropzoneContent(
                      label: widget.label,
                      isEnabled: isEnabled,
                    )
                  : _EmptyDropzoneContent(
                      label: widget.label,
                      isEnabled: isEnabled,
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

class _EmptyDropzoneContent extends StatelessWidget {
  final String label;
  final bool isEnabled;

  const _EmptyDropzoneContent({required this.label, required this.isEnabled});

  @override
  Widget build(BuildContext context) {
    final iconColor = isEnabled ? context.textPrimary : context.textDisabled;
    final textColor = isEnabled ? context.textTertiary : context.textDisabled;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.image_outlined, color: iconColor, size: 36),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: textColor),
        ),
      ],
    );
  }
}

class _CompactDropzoneContent extends StatelessWidget {
  final String label;
  final bool isEnabled;

  const _CompactDropzoneContent({required this.label, required this.isEnabled});

  @override
  Widget build(BuildContext context) {
    final iconColor = isEnabled ? context.textPrimary : context.textDisabled;
    final textColor = isEnabled ? context.textTertiary : context.textDisabled;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.add, color: iconColor, size: 22),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: textColor),
          ),
        ),
      ],
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final BorderRadius borderRadius;

  const _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final path = Path()..addRRect(borderRadius.toRRect(Offset.zero & size));

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
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.borderRadius != borderRadius;
  }
}
