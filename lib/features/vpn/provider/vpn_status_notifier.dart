import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'vpn_status_notifier.g.dart';

@Riverpod(keepAlive: true)
class VPNStatusNotifier extends _$VPNStatusNotifier {
  @override
  Stream<LanternStatus> build() async* {
    yield* ref.read(lanternServiceProvider).watchVPNStatus();
  }
}
