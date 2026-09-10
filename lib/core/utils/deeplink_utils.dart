/// An OAuth callback query carries either a `token` (login succeeded) or a
/// `result` flag (`result=false` plus the account's device[...] list when the
/// login hit the device limit).
bool isOAuthCallbackResult(Uri uri) =>
    uri.queryParameters.containsKey('token') ||
    uri.queryParameters.containsKey('result');

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
