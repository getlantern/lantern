import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/loading_indicator.dart';

@RoutePage(name: 'PrivateServerDeploy')
class PrivateServerDeploy extends StatelessWidget {
  const PrivateServerDeploy({super.key});

  @override
  Widget build(BuildContext context) {
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
