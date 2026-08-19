import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/models/user_message.dart';

void main() {
  Map<String, Object?> message({
    String surface = 'snackbar',
    Object? action = const {
      'type': 'open_https_url',
      'url': 'https://getlantern.org/plans',
    },
  }) => {
    'display_id': 'campaign-1:generation-2',
    'campaign_id': 'campaign-1',
    'revision_id': 'revision-3',
    'delivery_id': 'delivery-4',
    'surface': surface,
    'locale': 'en-US',
    'body': 'A localized message',
    'button_label': 'View plans',
    'action': action,
    'expires_at': DateTime.now()
        .toUtc()
        .add(const Duration(hours: 1))
        .toIso8601String(),
  };

  test('parses the common v1 message contract', () {
    final parsed = UserMessage.tryParse(jsonEncode(message()));

    expect(parsed, isNotNull);
    expect(parsed!.surface, UserMessageSurface.snackbar);
    expect(parsed.action!.type, UserMessageActionType.openHttpsUrl);
    expect(parsed.action!.url, Uri.parse('https://getlantern.org/plans'));
  });

  test('supports actionless messages and open-plans actions', () {
    expect(
      UserMessage.tryParse(jsonEncode(message(action: null)))!.action,
      isNull,
    );

    final parsed = UserMessage.tryParse(
      jsonEncode(message(action: const {'type': 'open_plans'})),
    );
    expect(parsed!.action!.type, UserMessageActionType.openPlans);
  });

  test('drops unknown surfaces and degrades unsupported actions', () {
    expect(UserMessage.tryParse(jsonEncode(message(surface: 'modal'))), isNull);
    final unsafe = UserMessage.tryParse(
      jsonEncode(
        message(
          action: const {'type': 'open_https_url', 'url': 'lantern://internal'},
        ),
      ),
    );
    expect(unsafe, isNotNull);
    expect(unsafe!.action, isNull);

    final unknown = UserMessage.tryParse(
      jsonEncode(message(action: const {'type': 'future_action'})),
    );
    expect(unknown, isNotNull);
    expect(unknown!.action, isNull);
  });

  test('rejects credential-bearing HTTPS actions', () {
    final parsed = UserMessage.tryParse(
      jsonEncode(
        message(
          action: const {
            'type': 'open_https_url',
            'url': 'https://user:secret@example.com/path',
          },
        ),
      ),
    );
    expect(parsed, isNotNull);
    expect(parsed!.action, isNull);
  });

  test('returns null for no message and expired content', () {
    expect(UserMessage.tryParse('null'), isNull);
    final expired = message();
    expired['expires_at'] = DateTime.now()
        .toUtc()
        .subtract(const Duration(seconds: 1))
        .toIso8601String();
    expect(UserMessage.tryParse(jsonEncode(expired)), isNull);
  });
}
