import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';

@RoutePage(name: 'ManuallyServerSetup')
class ManuallyServerSetup extends StatefulHookConsumerWidget {
  const ManuallyServerSetup({super.key});

  @override
  ConsumerState<ManuallyServerSetup> createState() =>
      _ManuallyServerSetupState();
}

class _ManuallyServerSetupState extends ConsumerState<ManuallyServerSetup> {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final accessKeyController = useTextEditingController();

    return BaseScreen(
      title: 'set_up_your_server'.i18n,
      body: ListView(
        children: <Widget>[
          SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1. ${'set_up_your_server'.i18n}',
                  style: textTheme.titleMedium,
                ),
                SizedBox(height: 16),
                PrimaryButton(
                  icon: AppImagePaths.github,
                  iconColor: AppColors.white,
                  label: 'view_instructions_github'.i18n,
                  onPressed: () {
                    UrlUtils.openWithSystemBrowser(
                        AppUrls.manuallyServerSetupURL);
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "2. ${'name_your_server'.i18n}",
                  style: textTheme.titleMedium,
                ),
                SizedBox(height: 16),
                AppTextField(
                  label: 'server_nickname'.i18n,
                  hintText: "server_name".i18n,
                  prefixIcon: AppImage(path: AppImagePaths.server),
                ),
                SizedBox(height: 4),
                Center(
                  child: Text(
                    "how_server_appears".i18n,
                    style: textTheme.labelMedium!.copyWith(
                      color: AppColors.gray6,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "2.  ${'server_access_key'.i18n}",
                  style: textTheme.titleMedium,
                ),
                SizedBox(height: 16),
                AppTextField(
                  hintText: "server_name".i18n,
                  label: 'access_key'.i18n,
                  controller: accessKeyController,
                  prefixIcon: AppImage(path: AppImagePaths.key),
                  suffixIcon: GestureDetector(
                    onTap: openQrCodeScanner,
                    child: AppImage(path: AppImagePaths.qrCodeScanner),
                  ),
                ),
                SizedBox(height: 16),
                PrimaryButton(
                  enabled: accessKeyController.text.isNotEmpty,
                  label: 'verify_server'.i18n,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void openQrCodeScanner() {
    appRouter.push(QrCodeScanner());
  }
}
