class DeepLinkCallbackManager {
  static final DeepLinkCallbackManager _instance = DeepLinkCallbackManager._internal();

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

