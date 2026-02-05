import 'package:lantern/core/models/developer_mode.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'developer_mode_notifier.g.dart';

@Riverpod(keepAlive: true)
class DeveloperModeNotifier extends _$DeveloperModeNotifier {
  @override
  DeveloperMode build() {
    // Start with defaults immediately (sync build),
    // then hydrate from Go.
    _hydrate();
    return DeveloperMode.initial();
  }

  Future<void> _hydrate() async {
    final svc = ref.read(lanternServiceProvider);
    final res = await svc.getDeveloperMode();
    res.match(
      (err) => null,
      (dev) => state = dev,
    );
  }

  Future<void> updateDeveloperSettings(DeveloperMode dev) async {
    final prev = state;
    state = dev;

    final svc = ref.read(lanternServiceProvider);
    final res = await svc.setDeveloperMode(dev);

    res.match(
      (err) {
        // revert on failure
        state = prev;
      },
      (_) {},
    );
  }
}
