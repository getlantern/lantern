import 'dart:io';

import 'package:lantern/core/common/common.dart';
import 'package:store_checker/store_checker.dart';

class StoreUtils {
  bool _isPlayStoreVersion = false;

  Future<void> init() async {
    if (!Platform.isAndroid) return;
    Source installationSource = await StoreChecker.getSource;
    appLogger.info('Installation source: $installationSource');
    if (installationSource == Source.IS_INSTALLED_FROM_PLAY_STORE) {
      appLogger.info('App is installed from Play Store');
      _isPlayStoreVersion = true;
    } else {
      appLogger.info('App is side-loaded or installed from unknown source');
      _isPlayStoreVersion = false;
    }
  }

  bool isSideLoaded() {
    if (Platform.isIOS || (Platform.isAndroid && _isPlayStoreVersion)) {
      return false;
    }
    // For other platforms, it should be false
    return true;
  }
}
