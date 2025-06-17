import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/loading_indicator.dart';
import 'package:lantern/features/private_server/provider/private_server_notifier.dart';

@RoutePage(name: 'PrivateServerDeploy')
class PrivateServerDeploy extends HookConsumerWidget {
  final String serverName;

  const PrivateServerDeploy({
    super.key,
    required this.serverName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
}
