import 'package:lantern/core/models/developer_mode.dart';
import 'package:lantern/core/services/injection_container.dart' show sl;
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'developer_mode_notifier.g.dart';

@Riverpod(keepAlive: true)
class DeveloperModeNotifier extends _$DeveloperModeNotifier {
  LocalStorageService get _storage => sl<LocalStorageService>();

  @override
  DeveloperMode build() =>
      _storage.getDeveloperMode() ?? DeveloperMode.initial();

  Future<void> updateDeveloperSettings(DeveloperMode dev) async {
    state = dev;
    await _storage.saveDeveloperMode(dev);
  }
}
