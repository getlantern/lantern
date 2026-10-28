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
