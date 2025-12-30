import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';

import '../common/common.dart';

class AppPinField extends StatelessWidget {
  final Function(String)? onCompleted;
  final Function(String)? onChanged;
  final TextEditingController? controller;

  const AppPinField({
    super.key,
    this.onCompleted,
    this.onChanged,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.gray3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          AppImage(path: AppImagePaths.number),
          SizedBox(width: defaultSize),
          Expanded(
            child: Shortcuts(
              shortcuts: <ShortcutActivator, Intent>{
                // Command+V for macOS
                const SingleActivator(LogicalKeyboardKey.keyV, meta: true):
                    const PasteIntent(),
                // Ctrl+V for other platforms (fallback)
                const SingleActivator(LogicalKeyboardKey.keyV, control: true):
                    const PasteIntent(),
              },
              child: Actions(
                actions: <Type, Action<Intent>>{
                  PasteIntent: CallbackAction<PasteIntent>(
                    onInvoke: (PasteIntent intent) {
                      _handlePaste();
                      return null;
                    },
                  ),
                },
                child: Pinput(
                  length: 6,
                  showCursor: true,
                  autofocus: true,
                  onCompleted: onCompleted,
                  onChanged: onChanged,
                  controller: controller,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  animationDuration: Duration(milliseconds: 100),
                  closeKeyboardWhenCompleted: true,
                  hapticFeedbackType: HapticFeedbackType.lightImpact,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  cursor: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 2,
                        height: 20,
                        color: AppColors.gray4,
                      ),
                    ],
                  ),
                  preFilledWidget: Container(
                    width: 15,
                    height: 1,
                    color: AppColors.gray4,
                  ),
                  defaultPinTheme: PinTheme(
                    width: 20,
                    height: 45,
                    textStyle: Theme.of(context).textTheme.titleMedium,
                    decoration: BoxDecoration(),
                  ),
                  focusedPinTheme: PinTheme(
                    width: 20,
                    height: 45,
                    textStyle: Theme.of(context).textTheme.titleMedium,
                    decoration: BoxDecoration(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    final digitsOnly = text.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length == 6) {
      controller?.text = digitsOnly;
      onCompleted?.call(digitsOnly);
    }
  }
}
