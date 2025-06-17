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
  @override
  Widget build(
    BuildContext context,
  ) {
    final serverState = ref.watch(privateServerNotifierProvider);
    if (serverState.status == 'EventTypeProvisioningCompleted') {
      appLogger.info("Private server deployment completed successfully.",
          serverState.data);
    }
    if (serverState.status == 'EventTypeProvisioningError') {
      // If the server is ready, open the browser
      appLogger.error("Private server deployment failed.", serverState.error);
    }
    if (serverState.status == 'EventTypeProvisioningCancelled') {
      appLogger.info("Private server deployment was cancelled.");
    }
    if (serverState.status == 'EventTypeServerTofuPermission') {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final List<dynamic> data = jsonDecode(serverState.data!);
      final certList = data.map((item) => CertSummary.fromJson(item)).toList();
      showFingerprintDialog(certList);
    });
    }

    final textTheme = Theme.of(context).textTheme;
    return BaseScreen(
      title: 'Deploying Private Server',
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Hang tight! Your Private Server is being set up. This may take a few minutes.',
              style: textTheme.bodyLarge!.copyWith(
                color: AppColors.gray8,
              ),
            ),
          ),
          LoadingIndicator(),
          SecondaryButton(
            label: 'Cancel Server Deployment',
            onPressed: () {},
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
          Text(
            'Confirm Fingerprint',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: 16),
          ...cert.map((e) => AppTile(
                icon: Icon(Icons.fingerprint),
                label: e.fingerprint,
                onPressed: () {
                  onConfirmFingerprint(e);
                  appRouter.pop();
                },
              )),
        ],
      ),
      action: [],
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
        context.showSnackBar('Cert set successfully.');
      },
    );
  }
}
