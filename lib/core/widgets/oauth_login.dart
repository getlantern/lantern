import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/models/user.dart';
import 'package:lantern/core/utils/country_code.dart';
import 'package:lantern/core/utils/deeplink_utils.dart';
import 'package:lantern/core/widgets/censored_dialog.dart';
import 'package:lantern/features/auth/device_limit_flow.dart';
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
              _handleOAuthPayload(
                type,
                ref,
                context,
                Map<String, dynamic>.from(result as Map),
              );
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
              _handleOAuthPayload(type, ref, context, p0);
            },
          );
        }
      },
    );
  }

  /// The OAuth callback either carries just a token (login succeeded) or a
  /// device-limit response (result=false plus the account's device[...] list
  /// and a token identifying the account). In the latter case load the
  /// account identity into the core so the removal is authorized, run the
  /// same device-removal flow as password sign-in, then restart the OAuth
  /// flow once a device has been freed up.
  Future<void> _handleOAuthPayload(
    SignUpMethodType type,
    WidgetRef ref,
    BuildContext context,
    Map<String, dynamic> payload,
  ) async {
    final devices = payload['result'] == 'false'
        ? _devicesFromPayload(payload)
        : const <DeviceModel>[];
    if (devices.isEmpty) {
      onResult(payload);
      return;
    }
    appLogger.warning(
      'OAuth login hit device limit (${devices.length} devices), '
      'starting device flow',
    );
    final token = payload['token'];
    if (token is String && token.isNotEmpty) {
      final identityResult = await ref
          .read(authProvider.notifier)
          .oAuthDeviceLimitCallback(token);
      final failure = identityResult.fold((f) => f, (_) => null);
      if (failure != null) {
        if (context.mounted) {
          context.showSnackBar(failure.localizedErrorMessage);
        }
        return;
      }
    }
    if (!context.mounted) return;
    await startDeviceLimitFlow(devices, () async {
      if (!context.mounted) return;
      await oAuthLogin(type, ref, context);
    });
  }

  static final _devicePattern = RegExp(r'^device\[(.+)\]$');

  List<DeviceModel> _devicesFromPayload(Map<String, dynamic> payload) {
    final devices = <DeviceModel>[];
    payload.forEach((key, value) {
      final match = _devicePattern.firstMatch(key);
      if (match != null) {
        devices.add(
          DeviceModel(
            deviceId: match.group(1)!,
            name: value?.toString() ?? '',
            created: 0,
          ),
        );
      }
    });
    return devices;
  }
}
