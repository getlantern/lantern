import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';

/// Explains how to add the Lantern home-screen widget. Shown from Settings on
/// platforms that ship the widget extension.
void showWidgetBottomSheet({required BuildContext context}) {
  // backgroundColor and shape come from bottomSheetTheme in app_theme.dart
  showModalBottomSheet(
    context: context,
    isDismissible: true,
    enableDrag: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => const _WidgetSheetContent(),
  );
}

class _WidgetSheetContent extends StatelessWidget {
  const _WidgetSheetContent();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final steps = [
      'widget_step_1'.i18n,
      'widget_step_2'.i18n,
      'widget_step_3'.i18n,
    ];

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'add_lantern_widget'.i18n,
                style: textTheme.headlineSmall!.copyWith(
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'add_lantern_widget_description'.i18n,
                style: textTheme.bodyMedium!.copyWith(
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              const _WidgetPreview(),
              const SizedBox(height: 24),
              for (var i = 0; i < steps.length; i++) ...[
                _StepRow(index: i + 1, text: steps[i]),
                if (i < steps.length - 1) const SizedBox(height: 12),
              ],
              const SizedBox(height: 24),
              PrimaryButton(
                buttonKey: const Key('widget_sheet.got_it'),
                label: 'got_it'.i18n,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Illustration of the home-screen widget, exported from Figma.
class _WidgetPreview extends StatelessWidget {
  const _WidgetPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: context.bgCallout,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const AppImage(
        path: AppImagePaths.widgetPreview,
        height: 106,
        useThemeColor: false,
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final int index;
  final String text;

  const _StepRow({required this.index, required this.text});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.textPrimary,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$index',
            style: textTheme.labelSmall!.copyWith(
              color: context.textInverse,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: textTheme.bodyMedium!.copyWith(color: context.textPrimary),
          ),
        ),
      ],
    );
  }
}
