import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/utils/deeplink_utils.dart';
import 'package:lantern/core/utils/ip_utils.dart';
import 'package:lantern/core/widgets/censored_dialog.dart';
import 'package:lantern/features/auth/add_email.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';

import '../../features/auth/provider/auth_notifier.dart';
import '../common/common.dart';
import '../services/injection_container.dart' show sl;

class OAuthLogin extends HookConsumerWidget {
  final SignUpMethodType methodType;
  final Function(Map<String, dynamic> token) onResult;

  const OAuthLogin({
    super.key,
    required this.methodType,
    required this.onResult,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (methodType == SignUpMethodType.apple) {
      return SecondaryButton(
        label: 'continue_with_apple'.i18n,
        icon: AppImagePaths.apple,
        onPressed: () => _handleSignIn(SignUpMethodType.apple, ref, context),
      );
    }
    return SecondaryButton(
      label: 'continue_with_google'.i18n,
      icon: AppImagePaths.google,
      onPressed: () => _handleSignIn(SignUpMethodType.google, ref, context),
    );
  }

  Future<void> _handleSignIn(
    SignUpMethodType type,
    WidgetRef ref,
    BuildContext context,
  ) async {
    if (await _isRegionAllowed(ref, context)) {
      await oAuthLogin(type, ref, context);
    }
  }

  Future<bool> _isRegionAllowed(WidgetRef ref, BuildContext context) async {
    final vpnStatus = ref.read(vpnNotifierProvider);
    if (vpnStatus == VPNStatus.connected) return true;

    try {
      context.showLoadingDialog();
      final country = await IPUtils.getUserCountry();
      context.hideLoadingDialog();

      // Proceed if country is unknown or not censored
      if (country == null || !IPUtils.censoredRegion.contains(country)) {
        return true;
      }

      return await _promptVpn(ref, context);
    } catch (e) {
      appLogger.error('Region check failed: $e');
      context.hideLoadingDialog();
      return true; // fallback to allow login
    }
  }

  Future<bool> _promptVpn(
    WidgetRef ref,
    BuildContext context,
  ) async {
    await showDialog(
      context: context,
      builder: (context) => CensoredDialog(
        done: () => oAuthLogin(methodType, ref, context),
      ),
    );
    return true;
  }

  Future<void> oAuthLogin(
      SignUpMethodType type, WidgetRef ref, BuildContext context) async {
    context.showLoadingDialog();
    final result =
        await ref.read(authNotifierProvider.notifier).oAuthLogin(type.name);
    result.fold(
      (failure) {
        context.hideLoadingDialog();
        context.showSnackBar(failure.localizedErrorMessage);
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
