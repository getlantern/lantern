import 'package:flutter/services.dart';
import 'package:lantern/core/common/common.dart';

extension ErrorExetension on Object {
  String get localizedDescription {
    // Check if the error is a PlatformException
    if (this is PlatformException) {
      // Extract the message from the PlatformException and strip the
      // radiance IPC wrapper (e.g. "ipc: status 401: actual error")
      // so only the upstream error is kept.
      String description = _stripIpcPrefix(
        (this as PlatformException).message ?? '',
      );
      if (description.contains("proxy_error")) {
        return "proxy_error".i18n;
      }
      if (description.contains("VPN client not setup")) {
        return "vpn_client_not_setup".i18n;
      }

      if (description.contains("user_not_found")) {
        return "user_not_found".i18n;
      }
      if (description.contains("invalid_code")) {
        return "invalid_code".i18n;
      }
      if (description.contains("recovery_not_found")) {
        return "recovery_not_found".i18n;
      }

      if (description.contains("wrong-link-code")) {
        return "wrong_link_code".i18n;
      }
      if (description.contains("we_are_experiencing_technical_difficulties")) {
        return "we_are_experiencing_technical_difficulties".i18n;
      }

      if (description.contains("wrong-reseller-code")) {
        return "wrong_seller_code".i18n;
      }
      if (description.contains(
            "unexpected status 400 body missing verifier or salt ",
          ) ||
          description.contains('unexpected status 403 body')) {
        return "user_not_found".i18n;
      }
      if (description.contains("user already exists") ||
          description.contains(
            "user with this legacy user ID already exists",
          )) {
        return "signup_error_user_exists".i18n;
      }

      if (description.contains("purchase_not_found") ||
          description.contains("user with provided email not found") ||
          description.contains("no valid purchases for user")) {
        return "purchase_not_found".i18n;
      }
      if (description.contains("err_while_sending_code")) {
        return "err_while_sending_code".i18n;
      }

      if (description.contains("error-wrong-code") ||
          description.contains("<error-email-not-verified>")) {
        return "invalid_code".i18n;
      }

      if (description.contains("error restoring purchase")) {
        return "purchase_restored_error".i18n;
      }

      if (description.contains("error restoring purchase")) {
        return "purchase_restored_error".i18n;
      }
      if (description.contains('Invalid referral')) {
        return "referral_code_invalid".i18n;
      }
      if (description.contains('Cannot use your own code for promotion')) {
        return "referral_code_own_invalid".i18n;
      }

      final categoryKey = _classifyVpnError(description);
      if (categoryKey != null) return categoryKey.i18n;

      return "an_error_occurred".i18n;
    }

    if (this is StateError) {
      final categoryKey = _classifyVpnError((this as StateError).message);
      if (categoryKey != null) return categoryKey.i18n;
      return "an_error_occurred".i18n;
    }
    if (this is Exception) {
      final categoryKey = _classifyVpnError((this as Exception).toString());
      if (categoryKey != null) return categoryKey.i18n;
      return "an_error_occurred".i18n;
    }

    return "an_error_occurred".i18n;
  }
}

///classifies VPN-related errors into user-friendly categories based on regex patterns.
const List<(String, String)> _vpnErrorPatterns = [
  (
    r'no such host|dns|network is unreachable|i/o timeout|no route to host|connection refused',
    'err_check_connection',
  ),
  (r'\b503\b|service unavailable', 'err_service_unavailable'),
  (r'ruleset|geosite|geoip|smart routing', 'err_ruleset_failed'),
  (
    r'tunnel|tun device|setup failed|failed to start vpn|libbox',
    'err_connection_failed',
  ),
];

String? _classifyVpnError(String description) {
  if (description.isEmpty) return null;
  for (final (pattern, key) in _vpnErrorPatterns) {
    if (RegExp(pattern, caseSensitive: false).hasMatch(description)) {
      return key;
    }
  }
  return null;
}

/// Strips the radiance IPC prefix from error messages.
/// e.g. "ipc: status 401: unexpected status 403 body forbidden"
///  → "unexpected status 403 body forbidden"
String _stripIpcPrefix(String message) {
  final match = RegExp(r'^ipc:\s*status\s+\d+:\s*').firstMatch(message);
  if (match != null) {
    return message.substring(match.end);
  }
  return message;
}

extension PurchaseErrorExtension on String {
  String get localizedDescription {
    if (this == 'BillingResponse.itemAlreadyOwned') {
      return "purchase_already_owned".i18n;
    }
    return this;
  }
}

extension FailureExtension on Object {
  Failure toFailure() {
    return Failure(
      error: toString(),
      localizedErrorMessage: localizedDescription,
    );
  }
}
