import 'dart:io';

import 'package:store_checker/store_checker.dart';

class StoreUtils {
  bool _isPlayStoreVersion = false;

  Future<void> init() async {
    if (!Platform.isAndroid) return;
    Source installationSource = await StoreChecker.getSource;

    if (installationSource == Source.IS_INSTALLED_FROM_PLAY_STORE ||
        installationSource == Source.IS_INSTALLED_FROM_PLAY_PACKAGE_INSTALLER) {
      _isPlayStoreVersion = true;
    } else {
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
