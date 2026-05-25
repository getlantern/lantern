import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/utils/country_code.dart';
import 'package:lantern/core/utils/deeplink_utils.dart';
import 'package:lantern/core/widgets/censored_dialog.dart';
import 'package:lantern/features/home/provider/country_code_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';

import '../../features/auth/provider/auth_notifier.dart';
import '../common/common.dart';
import '../services/injection_container.dart' show sl;

class OAuthLogin extends HookConsumerWidget {
  final SignUpMethodType methodType;
  final String? label;
  final Color? bgColor;
  final Color? foregroundColor;
  final bool? removeBorder;
  final Function(Map<String, dynamic> payload) onResult;

  const OAuthLogin({
    super.key,
    required this.methodType,
    this.label,
    required this.onResult,
    this.bgColor,
    this.foregroundColor,
    this.removeBorder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (methodType == SignUpMethodType.apple) {
      return SecondaryButton(
        label: label ?? 'continue_with_apple'.i18n,
        icon: AppImagePaths.apple,
        isTaller: true,
        bgColor: bgColor,
        removeBorder: removeBorder,
        foregroundColor: foregroundColor,
        onPressed: () => _handleSignIn(SignUpMethodType.apple, ref, context),
      );
    }
    return SecondaryButton(
      label: label ?? 'continue_with_google'.i18n,
      icon: AppImagePaths.google,
      isTaller: true,
      bgColor: bgColor,
      useThemeColor: false,
      removeBorder: removeBorder,
      foregroundColor: foregroundColor,
      onPressed: () => _handleSignIn(SignUpMethodType.google, ref, context),
    );
  }

  Future<void> _handleSignIn(
    SignUpMethodType type,
    WidgetRef ref,
    BuildContext context,
  ) async {
    final allowed = await _isRegionAllowed(ref, context);
    if (!allowed || !context.mounted) return;
    await oAuthLogin(type, ref, context);
  }

  Future<bool> _isRegionAllowed(WidgetRef ref, BuildContext context) async {
    final vpnStatus = ref.read(vpnProvider);
    if (vpnStatus == VPNStatus.connected) return true;

    final country = ref.read(countryCodeProvider);

    // Proceed if country is unknown or not censored.
    if (country.isEmpty ||
        !CountryCode.censoredRegions.contains(country.toUpperCase())) {
      return true;
    }
    return await _promptVpn(ref, context);
  }

  Future<bool> _promptVpn(WidgetRef ref, BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) =>
          CensoredDialog(done: () => oAuthLogin(methodType, ref, context)),
    );
    return true;
  }

  Future<void> oAuthLogin(
    SignUpMethodType type,
    WidgetRef ref,
    BuildContext context,
  ) async {
    context.showLoadingDialog();
    final result = await ref.read(authProvider.notifier).oAuthLogin(type.name);
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

          // Mobile sign-in needs the system browser for the deep link.
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
