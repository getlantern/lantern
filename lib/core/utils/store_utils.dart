import 'package:store_checker/store_checker.dart';

class StoreUtils {
  bool isPlayStoreVersion = false;

  Future<void> init() async {
    Source installationSource = await StoreChecker.getSource;

    if (installationSource == Source.IS_INSTALLED_FROM_PLAY_STORE ||
        installationSource == Source.IS_INSTALLED_FROM_PLAY_PACKAGE_INSTALLER) {
      isPlayStoreVersion = true;
    } else {
      isPlayStoreVersion = false;
    }
  }
}