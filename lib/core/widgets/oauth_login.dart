import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/utils/deeplink_utils.dart';
import 'package:lantern/features/auth/add_email.dart';
import 'package:lantern/features/auth/provider/oauth_notifier.dart';

import '../common/common.dart';

class OAuthLogin extends HookConsumerWidget {
  final SignUpMethodType methodType;
  final Function(Map<String,dynamic> token) onResult;

  const OAuthLogin({
    super.key,
    required this.methodType,
    required this.onResult,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (methodType == SignUpMethodType.google) {
      return SecondaryButton(
        label: 'continue_with_apple'.i18n,
        icon: AppImagePaths.apple,
        onPressed: () => oAuthLogin(SignUpMethodType.apple, ref, context),
      );
    }
    return SecondaryButton(
      label: 'continue_with_google'.i18n,
      icon: AppImagePaths.google,
      onPressed: () => oAuthLogin(SignUpMethodType.google, ref, context),
    );
  }

  Future<void> oAuthLogin(
      SignUpMethodType type, WidgetRef ref, BuildContext context) async {
    context.showLoadingDialog();
    final result =
        await ref.read(oAuthNotifierProvider.notifier).oAuthLogin(type.name);

    result.fold(
      (failure) {
        context.hideLoadingDialog();
        context.showSnackBarError(failure.localizedErrorMessage);
      },
      (url) async {
        context.hideLoadingDialog();
        appLogger.debug('OAuth URL: $url');
        if (PlatformUtils.isMobile) {
          // listen to handle the deep link
          sl<DeepLinkCallbackManager>().registerHandler((result) {
            appLogger.debug('DeepLink result: $result');
            if (result != null) {
              // Handle the deep link result here
              onResult(result as Map<String, dynamic>);
            }
          });

          /// For mobile we have to use system default browser
          UrlUtils.openWithSystemBrowser(url);
        } else {
          UrlUtils.openWebview<Map<String, dynamic>>(
            url,
            title: type.name.capitalize,
            onWebviewResult: (p0) {
              appLogger.debug('WebView result: $p0');
              onResult(p0);
                        },
          );
        }
      },
    );
  }
}
