import 'package:lantern/features/home/provider/local_storage_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/entity/developer_mode_entity.dart';

part 'developer_mode_notifier.g.dart';

@Riverpod(keepAlive: true)
class DeveloperModeNotifier extends _$DeveloperModeNotifier {
  @override
  DeveloperModeEntity build() {
    final devSetting = ref.read(localStorageProvider).getDeveloperSetting();
    if (devSetting != null) {
      return devSetting;
    }
    return DeveloperModeEntity.initial();
  }

  void updateTestPlayPurchaseEnabled(DeveloperModeEntity dev) {
    state = dev;
    ref.read(localStorageProvider).updateDeveloperSetting(state);
  }

  void updateTestStripePurchaseEnabled(DeveloperModeEntity dev) {
    state = dev;
    ref.read(localStorageProvider).updateDeveloperSetting(state);
  }
}
