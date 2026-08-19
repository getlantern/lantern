import 'dart:convert';

enum UserMessageSurface { snackbar }

enum UserMessageActionType { openHttpsUrl, openPlans }

class UserMessageAction {
  final UserMessageActionType type;
  final Uri? url;

  const UserMessageAction({required this.type, this.url});

  static UserMessageAction? fromJson(Object? value) {
    if (value == null) return null;
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid user-message action');
    }
    switch (value['type']) {
      case 'open_https_url':
        final rawUrl = value['url'];
        final url = rawUrl is String ? Uri.tryParse(rawUrl) : null;
        if (url == null || url.scheme != 'https' || url.host.isEmpty) {
          throw const FormatException('Invalid HTTPS user-message action');
        }
        return UserMessageAction(
          type: UserMessageActionType.openHttpsUrl,
          url: url,
        );
      case 'open_plans':
        return const UserMessageAction(type: UserMessageActionType.openPlans);
      default:
        throw const FormatException('Unsupported user-message action');
    }
  }
}

/// Presentation-ready message returned by the common user-message contract.
/// Campaign targeting and authoring state intentionally do not cross this API.
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

  bool get isExpired => !expiresAt.isAfter(DateTime.now().toUtc());

  /// Parses a bridge response. Unknown surface/action values are ignored by
  /// returning null, keeping future server enum values safe for older apps.
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
    } on Object {
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
