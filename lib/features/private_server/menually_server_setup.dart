import 'dart:convert';

import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/private_server_status.dart';
import 'package:lantern/features/private_server/provider/private_server_notifier.dart';

import '../../core/models/private_server_entity.dart';
import '../../core/services/injection_container.dart';

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
    final nameController = useTextEditingController();
    final buttonValid = useState(false);
    final serverState = ref.watch(privateServerNotifierProvider);

    useEffect(() {
      if (serverState.status == 'EventTypeServerTofuPermission') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.hideLoadingDialog();
          final List<dynamic> data = jsonDecode(serverState.data!);
          final certList =
              data.map((item) => CertSummary.fromJson(item)).toList();
          showFingerprintDialog(certList);
        });
      }
      if (serverState.status == 'EventTypeProvisioningCompleted') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          appLogger.info("Private server deployment completed successfully.",
              serverState.data);
          final data = jsonDecode(serverState.data!);
          final serverData = PrivateServerEntity.fromJson(data);
          sl<LocalStorageService>().savePrivateServer(serverData);
          showSuccessDialog();
        });
      }
      return null;
    }, [serverState.status]);

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
                  controller: nameController,
                  onChanged: (value) {
                    buttonValid.value = (value.isNotEmpty &&
                        accessKeyController.text.isNotEmpty);
                  },
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
                  hintText: "access_key".i18n,
                  label: 'access_key'.i18n,
                  controller: accessKeyController,
                  prefixIcon: AppImage(path: AppImagePaths.key),
                  onChanged: (value) {
                    buttonValid.value =
                        (value.isNotEmpty && nameController.text.isNotEmpty);
                  },
                  suffixIcon: PlatformUtils.isMobile
                      ? GestureDetector(
                          onTap: () => openQrCodeScanner(accessKeyController),
                          child: AppImage(path: AppImagePaths.qrCodeScanner),
                        )
                      : SizedBox.shrink(),
                ),
                SizedBox(height: 16),
                PrimaryButton(
                  // enabled: buttonValid.value,
                  label: 'verify_server'.i18n,
                  onPressed: () => onVerifyServer(
                      accessKeyController.text, nameController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void openQrCodeScanner(TextEditingController accessKeyController) {
    appRouter.push(QrCodeScanner()).then(
      (value) {
        if (value != null) {
          try {
            final rawValue = value as String;
            accessKeyController.text = rawValue;
          } catch (e) {
            appLogger.error("Error parsing QR code: $e");
          }
        }
      },
    );
  }

  Future<void> onVerifyServer(String scannerValue, String tag) async {
    if (scannerValue.isEmpty) {
      appLogger.error("Scanner value is empty");
      return;
    }
    final url = Uri.parse(scannerValue);
    appLogger.info("Verifying server with URL: $url");
    final data = url.queryParameters;
    final ip = data['ip'] ?? '';
    final port = data['port'] ?? '';
    final accessKey = data['token'] ?? '';

    context.showLoadingDialog();
    final result = await ref
        .read(privateServerNotifierProvider.notifier)
        .addServerManually(ip, port, accessKey, tag);
    result.fold(
      (failure) {
        appLogger
            .error("Failed to add server: ${failure.localizedErrorMessage}");
        context.hideLoadingDialog();
        context.showSnackBar(failure.localizedErrorMessage);
      },
      (_) {
        appLogger.info("Server added successfully.");
        context.hideLoadingDialog();
      },
    );
  }

  void showFingerprintDialog(List<CertSummary> cert) {
    final textTheme = Theme.of(context).textTheme;
    AppDialog.customDialog(
      context: context,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(height: 24),
          Center(child: Icon(Icons.fingerprint, size: 40)),
          SizedBox(height: 16),
          Text(
            'confirm_server_fingerprint'.i18n,
            style: textTheme!.titleLarge,
          ),
          SizedBox(height: 16),
          Text(
            'server_fingerprint'.i18n,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          Text(
            cert.first.fingerprint,
            style: textTheme!.bodyMedium,
          ),
        ],
      ),
      action: [
        AppTextButton(
          label: "confirm_fingerprint".i18n,
          textColor: AppColors.blue6,
          onPressed: () {
            onConfirmFingerprint(cert.first);
            appRouter.pop();
          },
        ),
      ],
    );
  }

  Future<void> onConfirmFingerprint(CertSummary cert) async {
    context.showLoadingDialog();
    final result = await ref
        .read(privateServerNotifierProvider.notifier)
        .setCert(cert.fingerprint);

    result.fold(
      (failure) {
        context.hideLoadingDialog();
        // Handle failure case, e.g., show an error message
        appLogger.error("Failed to set cert: ${failure.localizedErrorMessage}");
        context.showSnackBar(failure.localizedErrorMessage);
      },
      (_) {
        context.hideLoadingDialog();
        // Handle success case, e.g., navigate to the next screen or show a success message
        appLogger.info("Cert set successfully.");
      },
    );
  }

  void showSuccessDialog() {
    final textTheme = Theme.of(context).textTheme;
    AppDialog.customDialog(
      context: context,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(height: 24),
          Center(child: AppImage(path: AppImagePaths.roundCorrect, height: 40)),
          SizedBox(height: 16),
          Text(
            'private_server_ready'.i18n,
            style: textTheme!.titleLarge,
          ),
          SizedBox(height: 16),
          Text(
            'private_server_ready_message'.i18n,
            style: textTheme!.bodyLarge,
          ),
        ],
      ),
      action: [
        AppTextButton(
          label: "close".i18n,
          onPressed: () {
            appRouter.popUntilRoot();
          },
          textColor: AppColors.gray6,
        ),
        AppTextButton(
          label: "connect_now".i18n,
          textColor: AppColors.blue6,
          onPressed: () {
            appRouter.maybePop();
          },
        ),
      ],
    );
  }
}
