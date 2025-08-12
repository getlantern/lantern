import 'dart:math';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/spinner.dart';
import 'package:lantern/features/private_server/provider/private_server_notifier.dart';

@RoutePage(name: 'DeployingServer')
class DeployingServer extends HookConsumerWidget {
  const DeployingServer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(privateServerNotifierProvider);
    final dialogShown = useRef(false);

    ref.listen(privateServerNotifierProvider, (previous, next) {
      if (dialogShown.value) return;

      switch (next.status) {
        case 'EventTypeProvisioningCompleted':
          dialogShown.value = true;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => SuccessStatusModal(
              onConnect: () {
                dialogShown.value = false;
                Navigator.of(context).pop();
              },
              onClose: () {
                dialogShown.value = false;
                Navigator.of(context).pop();
                appRouter.popUntilRoot();
              },
            ),
          );
          break;

        case 'EventTypeProvisioningError':
        case 'EventTypeValidationError':
          dialogShown.value = true;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => ErrorStatusModal(
              onRetry: () {
                dialogShown.value = false;
                Navigator.of(context).pop();
              },
              onExit: () {
                dialogShown.value = false;
                Navigator.of(context).pop();
                appRouter.popUntilRoot();
              },
            ),
          );
          break;

        default:
          break;
      }
    });

    final isBusy = state.status == 'EventTypeProvisioningStarted' ||
        state.status == 'EventTypeValidationStarted' ||
        state.status == 'openBrowser' ||
        state.status == 'EventTypeOAuthCompleted';

    Future<void> onCancel() async {
      try {
        await ref
            .read(privateServerNotifierProvider.notifier)
            .cancelDeployment();
      } catch (_) {
        appRouter.popUntilRoot();
      }
    }

    return BaseScreen(
      title: 'deploying_private_server'.i18n,
      padded: true,
      body: PopScope(
        canPop: !isBusy,
        child: Container(
          color: const Color(0xFFF8FAFB),
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: Text(
                        _statusCopy(state.status),
                        textAlign: TextAlign.left,
                        style: AppTestStyles.bodyLarge.copyWith(
                          color: const Color(0xFF3D454D),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Spinner(),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: isBusy ? onCancel : appRouter.popUntilRoot,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1A1B1C),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32),
                          ),
                          side: const BorderSide(color: Color(0xFFA2A2A2)),
                        ),
                        child: Text(
                          'cancel_server_deployment'.i18n,
                          style: AppTestStyles.bodyLarge.copyWith(
                            color: const Color(0xFF1A1B1C),
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _statusCopy(String status) {
    switch (status) {
      case 'EventTypeValidationStarted':
        return 'validating_your_account'.i18n;
      case 'EventTypeProvisioningStarted':
        return 'deploying_server_status'.i18n;
      case 'EventTypeOAuthCompleted':
        return 'starting_validation'.i18n;
      default:
        return 'deploying_server_status'.i18n;
    }
  }
}

class ErrorStatusModal extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onExit;

  const ErrorStatusModal({
    super.key,
    required this.onRetry,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    return DeployStatusModal(
      title: 'server_setup_failed'.i18n,
      message: 'server_failed_message'.i18n,
      icon: AppImagePaths.errorIcon,
      primaryLabel: 'retry'.i18n,
      onPrimary: onRetry,
      secondaryLabel: 'exit'.i18n,
      onSecondary: onExit,
    );
  }
}

class SuccessStatusModal extends StatelessWidget {
  final VoidCallback onConnect;
  final VoidCallback onClose;

  const SuccessStatusModal({
    super.key,
    required this.onConnect,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return DeployStatusModal(
      title: 'server_ready_title'.i18n,
      message: 'server_ready_message'.i18n,
      icon: AppImagePaths.success,
      primaryLabel: 'connect_now'.i18n,
      onPrimary: onConnect,
      secondaryLabel: 'close'.i18n,
      onSecondary: onClose,
    );
  }
}

class DeployStatusModal extends StatelessWidget {
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final String? icon;

  const DeployStatusModal({
    super.key,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.gray3, width: 1),
      ),
      backgroundColor: AppColors.gray1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                AppImage(path: icon!, width: 56, height: 56),
                const SizedBox(height: 12),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTestStyles.headingMedium.copyWith(
                  color: AppColors.black1,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: t.bodyMedium?.copyWith(
                  color: const Color(0xFF3D454D),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (secondaryLabel != null && onSecondary != null)
                    TextButton(
                      onPressed: onSecondary,
                      child: Text(
                        secondaryLabel!,
                        style: t.titleSmall?.copyWith(
                          color: AppColors.lightGray,
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: onPrimary,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue6,
                      foregroundColor: AppColors.gray1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    child: Text(
                      primaryLabel,
                      style: t.titleSmall?.copyWith(
                        color: AppColors.gray1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
