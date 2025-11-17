import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_status_notifier.dart';

import '../common/common.dart';

class CensoredDialog extends ConsumerStatefulWidget {
  final OnPressed done;

  const CensoredDialog({super.key, required this.done});

  @override
  ConsumerState<CensoredDialog> createState() => _CensoredDialogState();
}

class _CensoredDialogState extends ConsumerState<CensoredDialog> {
  @override
  Widget build(BuildContext context) {
    ref.listen(
      vPNStatusProvider,
      (previous, next) {
        if (next.value?.status == VPNStatus.connected) {
          context.maybePop();
        }
      },
    );

    return AlertDialog(
      backgroundColor: AppColors.gray3,
      contentPadding: EdgeInsets.symmetric(horizontal: defaultSize),
      actionsPadding: EdgeInsets.only(
          top: defaultSize,
          bottom: defaultSize,
          left: defaultSize,
          right: defaultSize),
      // contentPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 24),
          Text('vpn_may_be_needed'.i18n,
              style: Theme.of(context).textTheme.headlineSmall),
          SizedBox(height: 16),
          Text('google_and_apple_sign_in_blocked'.i18n,
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
      actions: [
        AppTextButton(
          label: 'continue_without_vpn'.i18n,
          textColor: AppColors.gray8,
          onPressed: () {
            context.maybePop();
          },
        ),
        AppTextButton(
          label: 'turn_on_vpn'.i18n,
          onPressed: () async {
            final result =
                await ref.read(vpnProvider.notifier).startVPN();
            result.fold(
              (failure) {
                context.maybePop();
                context.showSnackBar(failure.localizedErrorMessage);
              },
              (_) {},
            );
          },
        ),
      ],
    );
  }
}
