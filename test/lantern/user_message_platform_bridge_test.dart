import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/lantern/lantern_platform_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('org.getlantern.lantern/method');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'pulls, refreshes, and acknowledges through the shared native channel',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'currentUserMessage') {
          return jsonEncode({
            'display_id': 'campaign-1:generation-2',
            'campaign_id': 'campaign-1',
            'revision_id': 'revision-3',
            'delivery_id': 'delivery-4',
            'surface': 'snackbar',
            'locale': 'en-US',
            'body': 'Localized content',
            'expires_at': DateTime.now()
                .toUtc()
                .add(const Duration(hours: 1))
                .toIso8601String(),
          });
        }
        return null;
      });

      final service = LanternPlatformService();
      final current = await service.currentUserMessage();
      current.fold(
        (failure) => fail('current message failed: $failure'),
        (message) => expect(message?.displayId, 'campaign-1:generation-2'),
      );
      final refresh = await service.refreshUserMessages();
      refresh.fold((failure) => fail('refresh failed: $failure'), (_) {});
      final acknowledge = await service.acknowledgeUserMessage(
        'campaign-1:generation-2',
      );
      acknowledge.fold(
        (failure) => fail('acknowledgment failed: $failure'),
        (_) {},
      );

      expect(calls.map((call) => call.method), [
        'currentUserMessage',
        'refreshUserMessages',
        'acknowledgeUserMessage',
      ]);
      expect(calls.last.arguments, 'campaign-1:generation-2');
    },
  );
}
