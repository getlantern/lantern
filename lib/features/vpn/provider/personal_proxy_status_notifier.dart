import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/features/helpers/models/helpers_view.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

/// How often the Private Locations tab reads radiance's status of the
/// friends this device invited, while it is shown.
const personalProxyStatusInterval = Duration(seconds: 5);

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

  @override
  Map<String, PersonalProxyStatus>? build() {
    ref.listen(vpnProvider, (_, next) {
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
      state = r.ok ? PersonalProxyStatus.parseAll(r.data) : null;
    } finally {
      _reading = false;
    }
  }
}
