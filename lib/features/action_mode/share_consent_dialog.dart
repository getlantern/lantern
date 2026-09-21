import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';

/// One disclosure for both sharing modes. The user is not asked to pick a
/// mode — that follows from whether their router supports port forwarding —
/// so the copy describes the worst case (their own IP as the exit) and the
/// relayed case, and the single choice is whether to share at all.
class ShareConsentDialog extends StatelessWidget {
  const ShareConsentDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AlertDialog(
      title: Text('share_consent_title'.i18n),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('share_consent_body_what'.i18n, style: textTheme.bodyMedium),
            const SizedBox(height: 12),
            Text('share_consent_body_ip'.i18n, style: textTheme.bodyMedium),
            const SizedBox(height: 12),
            Text(
              'share_consent_body_safety'.i18n,
              style: textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).hintColor,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('share_consent_decline'.i18n),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('share_consent_accept'.i18n),
        ),
      ],
    );
  }
}
