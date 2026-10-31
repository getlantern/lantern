import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' show Either, Left, Right;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/helpers/models/helpers_view.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';
import 'package:lantern/features/vpn/provider/personal_proxy_status_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

class _Vpn extends VpnNotifier {
  @override
  VPNStatus build() => VPNStatus.connected;

  void set(VPNStatus status) => state = status;
}

/// Answers personal_proxy_status from [replies], one per call, each only
/// once the test completes it.
class _Service implements LanternService {
  final replies = <Completer<Either<Failure, String>>>[];
  int calls = 0;

  @override
  Future<Either<Failure, String>> helperCall(
    String op,
    Map<String, dynamic> args,
  ) {
    expect(op, 'personal_proxy_status');
    calls++;
    final c = Completer<Either<Failure, String>>();
    replies.add(c);
    return c.future;
  }

  void answer(String body) => replies.removeAt(0).complete(Right(body));

  void fail() => replies
      .removeAt(0)
      .complete(Left(Failure(error: 'x', localizedErrorMessage: 'x')));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _live =
    '{"statuses":[{"tag":"helper-0123456789ab","direct":true,"rooms":false}]}';

void main() {
  late _Vpn vpn;
  late _Service service;
  late ProviderContainer container;

  setUp(() {
    HelpersNotifier.debugBuildEnabled = true;
    vpn = _Vpn();
    service = _Service();
    container = ProviderContainer(
      overrides: [
        vpnProvider.overrideWith(() => vpn),
        lanternServiceProvider.overrideWithValue(service),
      ],
    );
    container.listen(personalProxyStatusProvider, (_, _) {});
  });

  tearDown(() {
    container.dispose();
    HelpersNotifier.debugBuildEnabled = null;
  });

  PersonalProxyStatusNotifier notifier() =>
      container.read(personalProxyStatusProvider.notifier);
  Map<String, PersonalProxyStatus>? status() =>
      container.read(personalProxyStatusProvider);

  test('a read applies radiance status', () async {
    final poll = notifier().poll();
    service.answer(_live);
    await poll;
    expect(status()?['helper-0123456789ab']?.direct, isTrue);
  });

  test('a disconnect during a read discards its answer', () async {
    final poll = notifier().poll();
    vpn.set(VPNStatus.disconnected);
    service.answer(_live);
    await poll;
    expect(status(), isNull);
  });

  test('a failed read clears the status that was live', () async {
    var poll = notifier().poll();
    service.answer(_live);
    await poll;
    expect(status(), isNotNull);

    poll = notifier().poll();
    service.fail();
    await poll;
    expect(status(), isNull);

    poll = notifier().poll();
    service.answer(_live);
    await poll;
    poll = notifier().poll();
    service.answer('{"error":"unavailable"}');
    await poll;
    expect(status(), isNull, reason: 'an error answer clears it too');
  });

  test('overlapping polls send one request', () async {
    final first = notifier().poll();
    await notifier().poll();
    expect(service.calls, 1);
    service.answer(_live);
    await first;
    expect(status(), isNotNull);
  });
}
