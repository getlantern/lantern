import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/macos_extension_state.dart';
import 'package:lantern/features/macos_extension/provider/macos_extension_notifier.dart';

@RoutePage(name: 'MacOSExtensionDialog')
class MacOSExtensionDialog extends StatefulHookConsumerWidget {
  const MacOSExtensionDialog({super.key});

  @override
  ConsumerState<MacOSExtensionDialog> createState() =>
      _MacOSExtensionDialogState();
}

class _MacOSExtensionDialogState extends ConsumerState<MacOSExtensionDialog> {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final systemExtensionStatus = ref.watch(macosExtensionNotifierProvider);
    appLogger.info(
        "Current System Extension Status: ${systemExtensionStatus.status}");
    useEffect(() {
      if (systemExtensionStatus.status == SystemExtensionStatus.error) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          appLogger.error(
              "Error fetching System Extension Status: ${systemExtensionStatus.message}");
          AppDialog.errorDialog(
              context: context,
              title: 'error'.i18n,
              content: systemExtensionStatus.message ??
                  'unknown_error_occurred'.i18n);
        });
      }
      if (systemExtensionStatus.status == SystemExtensionStatus.installed ||
          systemExtensionStatus.status == SystemExtensionStatus.activated) {
        appLogger.info(
            "System Extension is installed and activated. Closing dialog.");
        appRouter.pop();
      }
      return null;
    }, [systemExtensionStatus.status]);

    return BaseScreen(
      title: '',
      appBar: CustomAppBar(
        leading: SizedBox(),
        title: LanternLogo(),
        actions: [
          CloseButton(),
        ],
        backgroundColor: AppColors.white,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          AppImage(path: AppImagePaths.sysDialog),
          const SizedBox(height: 48.0),
          Text('enable_network_extension'.i18n,
              style: textTheme.headlineSmall!.copyWith(color: AppColors.gray8),
              textAlign: TextAlign.center),
          const SizedBox(height: 16.0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              'enable_network_extension_message'.i18n,
              style: textTheme.bodyLarge!.copyWith(
                color: AppColors.gray8,
              ),
            ),
          ),
          const SizedBox(height: 16.0),
          RichText(
            text: TextSpan(
              style: textTheme.bodyLarge!.copyWith(color: AppColors.gray7),
              children: [
                TextSpan(text: 'click'.i18n),
                WidgetSpan(child: SizedBox(width: 4.0)),
                TextSpan(
                  text: 'open_system_settings'.i18n,
                  style: AppTestStyles.bodyLargeBold.copyWith(
                    color: AppColors.gray8,
                  ),
                ),
                WidgetSpan(child: SizedBox(width: 4.0)),
                TextSpan(text: 'when_prompted'.i18n),
              ],
            ),
          ),
          SizedBox(height: 48.0),
          PrimaryButton(
            label: systemExtensionStatus.status ==
                    SystemExtensionStatus.requiresApproval
                ? 'activate_extension'.i18n
                : 'install_now'.i18n,
            isTaller: true,
            onPressed: () => onInstall(ref, context, systemExtensionStatus),
          ),
          const SizedBox(height: 16.0),
          SecondaryButton(
            label: 'learn_more'.i18n,
            isTaller: true,
            onPressed: onLearnMore,
          )
        ],
      ),
    );
  }

  Future<void> onInstall(WidgetRef ref, BuildContext context,
      MacOSExtensionState systemExtensionStatus) async {
    appLogger.info("Current System Extension Status: $systemExtensionStatus");
    if (systemExtensionStatus.status ==
        SystemExtensionStatus.requiresApproval) {
      ref.read(macosExtensionNotifierProvider.notifier).openSystemExtension();
      appLogger.info("Opening System Settings for Approval");
      return;
    }

    appLogger.info("Triggering System Extension Installation");
    final result = await ref
        .read(macosExtensionNotifierProvider.notifier)
        .triggerSystemExtensionInstallation();

    result.fold(
      (failure) {
        appLogger.error("Failure: ${failure.localizedErrorMessage}");
        AppDialog.errorDialog(
            context: context,
            title: 'error'.i18n,
            content: failure.localizedErrorMessage);
      },
      (result) {
        appLogger.info("System Extension Installation Triggered: $result");
      },
    );
  }

  void onLearnMore() {}
}
