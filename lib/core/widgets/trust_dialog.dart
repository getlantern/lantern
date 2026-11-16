import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';

/// The "trust whoever runs this" dialog: a shield, [title], the
/// [paragraphs] in order, and one Got it button. Join Private Server and
/// Invite a Personal Proxy show it with their own text.
Future<void> showTrustDialog(
  BuildContext context, {
  required String title,
  required List<String> paragraphs,
  Key? key,
}) {
  final textTheme = Theme.of(context).textTheme;
  return AppDialog.customDialog(
    context: context,
    // Three paragraphs: on a small phone with large text they scroll.
    content: SingleChildScrollView(
      child: Column(
        key: key,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: 16),
          AppImage(
            path: AppImagePaths.security,
            height: 40,
            color: context.textPrimary,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          for (final paragraph in paragraphs) ...[
            const SizedBox(height: 16),
            Text(paragraph, style: textTheme.bodyMedium),
          ],
        ],
      ),
    ),
    action: [
      PrimaryButton(
        label: 'got_it'.i18n,
        // showDialog puts the dialog on the root navigator.
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
      ),
    ],
  );
}
