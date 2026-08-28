import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_dimens.dart';
import 'package:lantern/core/common/app_semantic_colors.dart';
import 'package:lantern/core/models/user_message.dart';

class UserMessageSnackbar extends StatelessWidget {
  const UserMessageSnackbar({
    required this.message,
    required this.onAction,
    required this.onDismiss,
    super.key,
  });

  static const bodyKey = Key('user_message.snackbar.body');
  static const actionKey = Key('user_message.snackbar.action');
  static const closeKey = Key('user_message.snackbar.close');

  final UserMessage message;
  final ValueChanged<UserMessageAction> onAction;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final action = message.action;
    return Positioned(
      left: 16,
      right: 16,
      top: 0,
      bottom: 16,
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: double.infinity,
            child: Material(
              key: ValueKey('user_message.snackbar.${message.displayId}'),
              elevation: 6,
              color: context.bgSnackbar,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: defaultPadding,
                child: Row(
                  children: [
                    Expanded(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                        ),
                        child: SingleChildScrollView(
                          child: Semantics(
                            liveRegion: true,
                            label: message.body,
                            excludeSemantics: true,
                            child: Text(
                              message.body,
                              key: bodyKey,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: context.textInverse),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (action != null && message.buttonLabel != null)
                      KeyedSubtree(
                        key: actionKey,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: context.textInverseColor,
                          ),
                          onPressed: () => onAction(action),
                          child: Text(message.buttonLabel!),
                        ),
                      ),
                    Semantics(
                      label: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      button: true,
                      child: ExcludeSemantics(
                        child: IconButton(
                          key: closeKey,
                          icon: const Icon(Icons.close),
                          color: context.textInverse,
                          onPressed: onDismiss,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
