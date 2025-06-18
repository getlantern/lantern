import 'dart:convert';

import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/private_server_status.dart';
import 'package:lantern/core/widgets/loading_indicator.dart';
import 'package:lantern/features/private_server/provider/private_server_notifier.dart';

@RoutePage(name: 'PrivateServerDeploy')
class PrivateServerDeploy extends StatefulHookConsumerWidget {
  final String serverName;

  const PrivateServerDeploy({
    super.key,
    required this.serverName,
  });

  @override
  ConsumerState<PrivateServerDeploy> createState() =>
      _PrivateServerDeployState();
}

class _PrivateServerDeployState extends ConsumerState<PrivateServerDeploy> {
  TextTheme? textTheme;

  @override
  Widget build(BuildContext context) {
    textTheme = Theme.of(context).textTheme;

    final serverState = ref.watch(privateServerNotifierProvider);
    if (serverState.status == 'EventTypeProvisioningCompleted') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appLogger.info("Private server deployment completed successfully.",
            serverState.data);
        showSuccessDialog();
      });
    }
    if (serverState.status == 'EventTypeProvisioningError') {
      // If the server is ready, open the browser
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appLogger.error("Private server deployment failed.", serverState.error);
        showErrorDialog();
      });
    }
    if (serverState.status == 'EventTypeProvisioningCancelled') {
      appLogger.info("Private server deployment was cancelled.");
    }
    if (serverState.status == 'EventTypeServerTofuPermission') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final List<dynamic> data = jsonDecode(serverState.data!);
        final certList =
            data.map((item) => CertSummary.fromJson(item)).toList();
        showFingerprintDialog(certList);
      });
    }

    return BaseScreen(
      title: 'Deploying Private Server',
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'private_server_setup_in_progress'.i18n,
              style: textTheme!.bodyLarge!.copyWith(
                color: AppColors.gray8,
              ),
            ),
          ),
          LoadingIndicator(),
          SecondaryButton(
            label: 'cancel_server_deployment'.i18n,
            onPressed: cancelDeployment,
          ),
        ],
      ),
    );
  }

  void showFingerprintDialog(List<CertSummary> cert) {
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
          label: "cancel_deployment".i18n,
          onPressed: () {
            appRouter.pop();
            cancelDeployment();
          },
          textColor: AppColors.gray6,
        ),
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

  void showSuccessDialog() {
    AppDialog.customDialog(
      context: context,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(height: 24),
          Center(child: AppImage(path: AppImagePaths.roundCorrect)),
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
          onPressed: () {},
        ),
      ],
    );
  }

  void showErrorDialog() {
    AppDialog.customDialog(
      context: context,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(height: 24),
          Center(child: AppImage(path: AppImagePaths.errorIcon)),
          SizedBox(height: 16),
          Text(
            'server_setup_failed'.i18n,
            style: textTheme!.titleLarge,
          ),
          SizedBox(height: 16),
          Text(
            'server_setup_failed_message'.i18n,
            style: textTheme!.bodyLarge,
          ),
        ],
      ),
      action: [
        AppTextButton(
          label: "exit".i18n,
          onPressed: () {
            appRouter.popUntilRoot();
          },
          textColor: AppColors.gray6,
        ),
        AppTextButton(
          label: "retry".i18n,
          textColor: AppColors.blue6,
          onPressed: () {
            appRouter.popUntil(
                (route) => (route.settings.name == 'PrivateServerSetup'));
          },
        ),
      ],
    );
  }

  Future<void> onConfirmFingerprint(CertSummary cert) async {
    final result = await ref
        .read(privateServerNotifierProvider.notifier)
        .setCert(cert.fingerprint);

    result.fold(
      (failure) {
        // Handle failure case, e.g., show an error message
        appLogger.error("Failed to set cert: ${failure.localizedErrorMessage}");
        context.showSnackBar(failure.localizedErrorMessage);
      },
      (_) {
        // Handle success case, e.g., navigate to the next screen or show a success message
        appLogger.info("Cert set successfully.");
      },
    );
  }

  Future<void> cancelDeployment() async {
    context.showLoadingDialog();
    final result = await ref
        .read(privateServerNotifierProvider.notifier)
        .cancelDeployment();

    result.fold(
      (l) {
        context.hideLoadingDialog();
        // Handle failure case, e.g., show an error message
        appLogger
            .error("Failed to cancel deployment: ${l.localizedErrorMessage}");
        context.showSnackBar(l.localizedErrorMessage);
      },
      (r) {
        // Handle success case, e.g., navigate to the next screen or show a success message
        context.hideLoadingDialog();
        appLogger.info("Deployment cancelled successfully.");
        context.showSnackBar('Deployment cancelled successfully.');

        appRouter.popUntilRoot();
      },
    );
  }
}
