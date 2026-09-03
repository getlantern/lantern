import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/models/user_message.dart';
import 'package:lantern/features/user_message/user_message_action_dispatcher.dart';

void main() {
  test('routes validated HTTPS and plans actions to typed callbacks', () async {
    final urls = <Uri>[];
    var plansCalls = 0;
    final dispatcher = UserMessageActionDispatcher(
      openHttpsUrl: (uri) async => urls.add(uri),
      openPlans: () async => plansCalls++,
    );

    await dispatcher.dispatch(
      UserMessageAction(
        type: UserMessageActionType.openHttpsUrl,
        url: Uri.parse('https://getlantern.org/plans'),
      ),
    );
    await dispatcher.dispatch(
      const UserMessageAction(type: UserMessageActionType.openPlans),
    );

    expect(urls, [Uri.parse('https://getlantern.org/plans')]);
    expect(plansCalls, 1);
  });

  test('refuses non-HTTPS, relative, and credential-bearing URLs', () async {
    final urls = <Uri>[];
    final dispatcher = UserMessageActionDispatcher(
      openHttpsUrl: (uri) async => urls.add(uri),
      openPlans: () async {},
    );

    for (final uri in [
      Uri.parse('http://getlantern.org'),
      Uri.parse('/relative'),
      Uri.parse('https://user:secret@getlantern.org'),
    ]) {
      await dispatcher.dispatch(
        UserMessageAction(type: UserMessageActionType.openHttpsUrl, url: uri),
      );
    }

    expect(urls, isEmpty);
  });
}
