import 'dart:math';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/spinner.dart';

@RoutePage(name: 'DeployingServer')
class DeployingServer extends HookConsumerWidget {
  const DeployingServer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useEffect(() {
      // Test code to display success or failure modal
      final timer = Future.delayed(const Duration(seconds: 3), () {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => Random().nextInt(100) < 50
                ? ErrorStatusModal()
                : SuccessStatusModal(),
          );
        }
      });
      return () => timer.ignore();
    }, []);

    return BaseScreen(
      title: 'deploying_private_server'.i18n,
      body: Container(
        color: const Color(0xFFF8FAFB),
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Status Text
            Padding(
              padding: const EdgeInsets.only(top: 32, bottom: 16),
              child: SizedBox(
                width: 329,
                child: Text(
                  'deploying_server_status'.i18n,
                  style: AppTestStyles.bodyLarge.copyWith(
                    color: const Color(0xFF3D454D),
                  ),
                  textAlign: TextAlign.left,
                ),
              ),
            ),
            Spinner(),

            // Cancel Button
            Padding(
              padding: const EdgeInsets.only(bottom: 32, top: 24),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1A1B1C),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                    side: const BorderSide(
                      color: Color(0xFFA2A2A2),
                    ),
                  ),
                  onPressed: () => appRouter.popUntilRoot(),
                  child: Text(
                    'cancel_server_deployment'.i18n,
                    style: AppTestStyles.bodyLarge.copyWith(
                      color: const Color(0xFF1A1B1C),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorStatusModal extends StatelessWidget {
  const ErrorStatusModal({super.key});

  @override
  Widget build(BuildContext context) {
    return DeployStatusModal(
      title: 'server_setup_failed'.i18n,
      message: 'server_failed_message'.i18n,
      primaryAction: 'retry'.i18n,
      onPrimary: () => Navigator.of(context).pop(),
      secondaryAction: 'exit'.i18n,
      onSecondary: () => Navigator.of(context).pop(),
      icon: AppImagePaths.error,
    );
  }
}

class SuccessStatusModal extends StatelessWidget {
  const SuccessStatusModal({super.key});

  @override
  Widget build(BuildContext context) {
    return DeployStatusModal(
      title: 'server_ready_title'.i18n,
      message: 'server_ready_message'.i18n,
      primaryAction: 'connect_now'.i18n,
      onPrimary: () => Navigator.of(context).pop(),
      secondaryAction: 'close'.i18n,
      onSecondary: () => Navigator.of(context).pop(),
      icon: AppImagePaths.success,
    );
  }
}

class DeployStatusModal extends StatelessWidget {
  final String title;
  final String message;
  final String primaryAction;
  final VoidCallback onPrimary;
  final String? secondaryAction;
  final VoidCallback? onSecondary;
  final String? icon;

  const DeployStatusModal({
    super.key,
    required this.title,
    required this.message,
    required this.primaryAction,
    required this.onPrimary,
    this.secondaryAction,
    this.onSecondary,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.gray3, width: 1),
      ),
      backgroundColor: AppColors.gray1,
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            if (icon != null) AppImage(path: icon!),
            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTestStyles.headingMedium.copyWith(
                color: AppColors.black1,
                height: 1.0,
              ),
            ),
            // Text(
            //   'Private Server is Ready',
            //   textAlign: TextAlign.center,
            //   style: TextStyle(
            //     color: const Color(0xFF1A1B1C),
            //     fontSize: 24,
            //     fontFamily: 'Urbanist',
            //     fontWeight: FontWeight.w600,
            //     height: 1,
            //   ),
            // ),

            const SizedBox(height: 16),
            // Message
            Text(
              message,
              style: AppTestStyles.bodyMedium.copyWith(
                color: const Color(0xFF3D454D),
                height: 1.64,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (secondaryAction != null && onSecondary != null)
                  GestureDetector(
                    onTap: onSecondary,
                    child: Text(
                      secondaryAction!,
                      style: AppTestStyles.bodyLarge.copyWith(
                        color: AppColors.lightGray,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        height: 1.25,
                      ),
                    ),
                  ),
                GestureDetector(
                  onTap: onPrimary,
                  child: Text(
                    primaryAction,
                    style: AppTestStyles.bodyLarge.copyWith(
                      color: AppColors.blue6,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
