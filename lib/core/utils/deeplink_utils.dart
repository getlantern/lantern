import 'package:lantern/core/common/app_build_info.dart';

/// OAuth callback: `token` on success, `result=false` with device[...] or `error`.
bool isOAuthCallbackResult(Uri uri) =>
    uri.queryParameters.containsKey('token') ||
    uri.queryParameters.containsKey('result');

/// Fallback message for any OAuth callback failure.
const oAuthSignInFailedKey = 'oauth_error_sign_in_failed';

/// Codes with a specific message; everything else uses [oAuthSignInFailedKey].
const _oAuthErrorMessageKeys = <String, String>{
  'unable_to_restore_session': 'oauth_error_session_expired',
  'unable_to_authenticate': 'oauth_error_provider_failed',
  'unable_to_get_email': 'oauth_error_no_email',
  'unable_to_add_device': 'oauth_error_add_device',
};

/// The i18n key for the `error` code of a failed OAuth callback.
String oAuthErrorMessageKey(String? code) =>
    _oAuthErrorMessageKeys[code] ?? oAuthSignInFailedKey;

class DeepLinkCallbackManager {
  static final DeepLinkCallbackManager _instance =
      DeepLinkCallbackManager._internal();

  factory DeepLinkCallbackManager() => _instance;
  DeepLinkCallbackManager._internal();

  void Function(dynamic data)? _handler;

  void registerHandler(void Function(dynamic data) handler) {
    _handler = handler;
  }

  void handleDeepLink(dynamic data) {
    _handler?.call(data);
    _handler = null; // Reset after use
  }
}

/// A helper invite link: `https://lantern.io/help#…`, `/help/#…` (also on
/// www.lantern.io) or `<APP_AUTH_SCHEME>://help#…`. Never in a build without
/// helper invites (stealth). The secret is the fragment: never log it.
bool isHelperInviteUri(Uri uri) {
  if (!AppBuildInfo.enableHelperInvites) return false;
  if (AppBuildInfo.isAppAuthUri(uri) && uri.host == 'help') return true;
  return uri.scheme == 'https' &&
      (uri.host == 'lantern.io' || uri.host == 'www.lantern.io') &&
      (uri.path == '/help' || uri.path == '/help/');
}

/// The canonical link for a helper invite URI, for the engine to parse.
String helperInviteLink(Uri uri) => 'https://lantern.io/help/#${uri.fragment}';
