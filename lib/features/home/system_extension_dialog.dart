import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/home/provider/system_extension_notifier.dart';

@RoutePage(name: 'SystemExtensionDialog')
class SystemExtensionDialog extends HookConsumerWidget {
  const SystemExtensionDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
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
              style: textTheme.headlineSmall, textAlign: TextAlign.center),
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
                  style: AppTestStyles.bodyLargeBold!.copyWith(
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
            label: 'install_now'.i18n,
            isTaller: true,
            onPressed: () => onInstall(ref, context),
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

  Future<void> onInstall(WidgetRef ref, BuildContext context) async {
    final result = await ref
        .read(systemExtensionNotifierProvider.notifier)
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
        appRouter.maybePop();
      },
    );
  }

  void onLearnMore() {}
}
