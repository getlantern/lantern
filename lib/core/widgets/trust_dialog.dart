import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';

/// The "trust whoever is on the other end" dialog: a shield, [title], the
/// [paragraphs] in order, and one button. Join Private Server, Invite a
/// Personal Proxy and Become a Personal Proxy show it with their own text.
///
/// As a [gate] it adds an "I understand the risks" check, and its Continue
/// button is disabled until that is checked: the answer is whether the user
/// continued. A gate can also be left, by its close button or a tap outside,
/// which answers false. Otherwise the button is Got It, and the answer is
/// false.
Future<bool> showTrustDialog(
  BuildContext context, {
  required String title,
  required List<String> paragraphs,
  Key? key,
  bool gate = false,
}) async {
  final textTheme = Theme.of(context).textTheme;
  final understood = ValueNotifier(false);
  var accepted = false;
  // showDialog puts the dialog on the root navigator.
  void close() => Navigator.of(context, rootNavigator: true).pop();
  try {
    await AppDialog.customDialog(
      context: context,
      // A gate asks before an action: it can be left without answering.
      barrierDismissible: gate,
      content: Stack(
        // The close button reaches into the dialog's padding.
        clipBehavior: Clip.none,
        children: [
          // Three paragraphs: on a small phone with large text they scroll.
          SingleChildScrollView(
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
                if (gate) ...[
                  const SizedBox(height: 16),
                  ValueListenableBuilder<bool>(
                    valueListenable: understood,
                    builder: (context, on, _) => InkWell(
                      key: const Key('trust_dialog.understand'),
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => understood.value = !on,
                      child: Row(
                        children: [
                          Checkbox(
                            value: on,
                            activeColor: context.textLink,
                            checkColor: context.bgElevated,
                            onChanged: (value) =>
                                understood.value = value ?? false,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'trust_understand_risks'.i18n,
                              style: textTheme.bodyMedium!.copyWith(
                                color: context.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // In the corner, 8px from the top and the right edge (the content
          // is inset 24 at the sides), over the shield's row: the shield
          // stays where the Got It dialog has it.
          if (gate)
            PositionedDirectional(
              top: 8,
              end: -16,
              child: IconButton(
                key: const Key('trust_dialog.close'),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                icon: const Icon(Icons.close),
                color: context.textPrimary,
                onPressed: close,
              ),
            ),
        ],
      ),
      action: [
        if (gate)
          ValueListenableBuilder<bool>(
            valueListenable: understood,
            builder: (_, on, _) => PrimaryButton(
              key: const Key('trust_dialog.continue'),
              label: 'continue'.i18n,
              enabled: on,
              onPressed: () {
                accepted = true;
                close();
              },
            ),
          )
        else
          PrimaryButton(label: 'got_it'.i18n, onPressed: close),
      ],
    );
  } finally {
    understood.dispose();
  }
  return accepted;
}
