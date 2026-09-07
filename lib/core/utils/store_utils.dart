import 'dart:io';

import 'package:lantern/core/services/logger_service.dart';
import 'package:store_checker/store_checker.dart';

bool resolveAndroidStoreVersion({
  required bool isPlayStoreBuild,
  required bool isSideLoaded,
  bool? developerOverride,
}) {
  return isPlayStoreBuild || (developerOverride ?? !isSideLoaded);
}

bool resolvePlayBillingAvailability({
  required bool isAndroid,
  required bool isStoreVersion,
  required bool isCountryKnown,
  required bool isCensoredRegion,
}) {
  return isAndroid && isStoreVersion && isCountryKnown && !isCensoredRegion;
}

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
