import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/features/helpers/models/helpers_view.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

/// How often a screen showing the friends this device invited reads
/// radiance's status of them, while it is shown.
const personalProxyStatusInterval = Duration(seconds: 5);

/// Reads [personalProxyStatusProvider] after the first frame and then every
/// [personalProxyStatusInterval] while the app is resumed, for as long as the
/// calling widget is built with [enabled]. It is local IPC, read only while a
/// screen shows friends, so nothing polls it otherwise.
void usePersonalProxyStatusPoll(WidgetRef ref, {required bool enabled}) {
  useEffect(() {
    if (!enabled) return null;
    final status = ref.read(personalProxyStatusProvider.notifier);
    // The first read waits for the frame: the effect runs during build,
    // when no provider may change.
    var active = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (active) unawaited(status.poll());
    });
    final timer = Timer.periodic(personalProxyStatusInterval, (_) {
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return;
      }
      unawaited(status.poll());
    });
    return () {
      active = false;
      timer.cancel();
    };
  }, [enabled]);
}

/// radiance's status of each friend this device invited, by outbound tag,
/// which decides whether a friend can be selected on their own (see
/// [HelperPairingView.selectable]). Null while unknown: before the first
/// read, while the VPN is not connected, and after a failed read.
final personalProxyStatusProvider =
    NotifierProvider<
      PersonalProxyStatusNotifier,
      Map<String, PersonalProxyStatus>?
    >(PersonalProxyStatusNotifier.new);

class PersonalProxyStatusNotifier
    extends Notifier<Map<String, PersonalProxyStatus>?> {
  bool _reading = false;

  /// Bumped on every change into or out of connected, so a read that spans
  /// a disconnect and reconnect cannot apply the old connection's answer.
  int _connection = 0;

  @override
  Map<String, PersonalProxyStatus>? build() {
    ref.listen(vpnProvider, (prev, next) {
      if (prev != next &&
          (prev == VPNStatus.connected || next == VPNStatus.connected)) {
        _connection++;
      }
      if (next != VPNStatus.connected) state = null;
    });
    return null;
  }

  /// Reads the status once. It is local IPC only, never lantern-cloud, and
  /// nothing is logged: the tags name the friends. With the VPN not
  /// connected nothing is read and the status is unknown.
  Future<void> poll() async {
    if (_reading || !HelpersNotifier.buildEnabled) return;
    if (ref.read(vpnProvider) != VPNStatus.connected) {
      if (state != null) state = null;
      return;
    }
    _reading = true;
    final connection = _connection;
    try {
      final res = await ref
          .read(lanternServiceProvider)
          .helperCall('personal_proxy_status', const {});
      if (!ref.mounted) return;
      final r = res.fold(
        (_) => HelperResult.failure('unavailable'),
        HelperResult.parse,
      );
      if (ref.read(vpnProvider) != VPNStatus.connected) {
        state = null;
        return;
      }
      if (connection != _connection) return;
      state = r.ok ? PersonalProxyStatus.parseAll(r.data) : null;
    } finally {
      _reading = false;
    }
  }
}
