import 'dart:convert';

enum UserMessageSurface { snackbar }

enum UserMessageActionType { openHttpsUrl, openPlans }

class UserMessageAction {
  final UserMessageActionType type;
  final Uri? url;

  const UserMessageAction({required this.type, this.url});

  static UserMessageAction? fromJson(Object? value) {
    if (value == null) return null;
    if (value is! Map<String, dynamic>) return null;
    switch (value['type']) {
      case 'open_https_url':
        final rawUrl = value['url'];
        final url = rawUrl is String ? Uri.tryParse(rawUrl) : null;
        if (url == null ||
            url.scheme.toLowerCase() != 'https' ||
            url.host.isEmpty ||
            url.userInfo.isNotEmpty) {
          return null;
        }
        return UserMessageAction(
          type: UserMessageActionType.openHttpsUrl,
          url: url,
        );
      case 'open_plans':
        final rawUrl = value['url'];
        if (rawUrl != null && rawUrl != '') {
          return null;
        }
        return const UserMessageAction(type: UserMessageActionType.openPlans);
      default:
        return null;
    }
  }
}

/// A message Lantern can display. Campaign targeting and authoring stay in
/// Lantern Cloud.
class UserMessage {
  final String displayId;
  final String campaignId;
  final String revisionId;
  final String deliveryId;
  final UserMessageSurface surface;
  final String locale;
  final String body;
  final String? buttonLabel;
  final UserMessageAction? action;
  final DateTime expiresAt;

  const UserMessage({
    required this.displayId,
    required this.campaignId,
    required this.revisionId,
    required this.deliveryId,
    required this.surface,
    required this.locale,
    required this.body,
    required this.expiresAt,
    this.buttonLabel,
    this.action,
  });

  bool get isExpired => isExpiredAt(DateTime.now().toUtc());

  bool isExpiredAt(DateTime now) => !expiresAt.isAfter(now.toUtc());

  /// Reads common-contract bridge JSON. Unknown surfaces are dropped; unknown
  /// or unsafe actions leave a body-only message.
  static UserMessage? tryParse(String encoded) {
    if (encoded.trim() == 'null') return null;
    try {
      final value = jsonDecode(encoded);
      if (value is! Map<String, dynamic>) return null;
      if (value['surface'] != 'snackbar') return null;

      final message = UserMessage(
        displayId: _requiredString(value, 'display_id'),
        campaignId: _requiredString(value, 'campaign_id'),
        revisionId: _requiredString(value, 'revision_id'),
        deliveryId: _requiredString(value, 'delivery_id'),
        surface: UserMessageSurface.snackbar,
        locale: _requiredString(value, 'locale'),
        body: _requiredString(value, 'body'),
        buttonLabel: _optionalString(value, 'button_label'),
        action: UserMessageAction.fromJson(value['action']),
        expiresAt: DateTime.parse(_requiredString(value, 'expires_at')).toUtc(),
      );
      return message.isExpired ? null : message;
    } on FormatException {
      return null;
    }
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Missing $key');
    }
    return value;
  }

  static String? _optionalString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! String || value.isEmpty) {
      throw FormatException('Invalid $key');
    }
    return value;
  }
}
