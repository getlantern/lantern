import 'dart:async';

import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'vpn_status_notifier.g.dart';

@Riverpod(keepAlive: true)
class VPNStatusNotifier extends _$VPNStatusNotifier {
  @override
  Stream<LanternStatus> build() {
    final statusStream = ref.read(lanternServiceProvider).watchVPNStatus();
    return statusStream.transform(
      StreamTransformer.fromHandlers(
        handleData: (status, sink) => sink.add(status),
        handleError: (e, stackTrace, sink) {
          appLogger.error('VPN status stream failed', e, stackTrace);
          sink.add(
            LanternStatus(
              status: VPNStatus.error,
              error: e.toString(),
              origin: VPNStatusOrigin.system,
            ),
          );
        },
      ),
    );
  }
}
