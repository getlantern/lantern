// Common file to export all common files
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lantern/core/common/app_build_info.dart';
import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/common/app_urls.dart';
import 'package:lantern/core/localization/i18n.dart';
import 'package:lantern/core/models/entity/private_server_entity.dart';
import 'package:lantern/core/models/entity/server_location_entity.dart';
import 'package:lantern/core/router/router.dart';
import 'package:lantern/core/services/local_storage.dart';
import 'package:lantern/core/services/logger_service.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/home/provider/home_notifier.dart';
import '../../lantern/lantern_service_notifier.dart';
import '../services/injection_container.dart';
import '../utils/store_utils.dart';

export 'package:lantern/core/common/app_asset.dart';
export 'package:lantern/core/common/app_buttons.dart';
export 'package:lantern/core/common/app_colors.dart';
export 'package:lantern/core/common/app_dialog.dart';
export 'package:lantern/core/common/app_dimens.dart';
export 'package:lantern/core/common/app_eum.dart';
export 'package:lantern/core/common/app_image_paths.dart';
export 'package:lantern/core/common/app_text_field.dart';
export 'package:lantern/core/common/app_theme.dart';
// Utils
export 'package:lantern/core/common/app_urls.dart';
export 'package:lantern/core/extensions/context.dart';
export 'package:lantern/core/extensions/error.dart';
export 'package:lantern/core/extensions/pointer.dart';
export 'package:lantern/core/extensions/ref.dart';
// Extensions
export 'package:lantern/core/extensions/string.dart';
export 'package:lantern/core/localization/i18n.dart';
// Routes
export 'package:lantern/core/router/router.gr.dart';
// DB
export 'package:lantern/core/services/local_storage.dart';
//Logger
export 'package:lantern/core/services/logger_service.dart';
export 'package:lantern/core/utils/failure.dart';
export 'package:lantern/core/utils/platform_utils.dart';
export 'package:lantern/core/utils/url_utils.dart';
export 'package:lantern/core/widgets/app_card.dart';
export 'package:lantern/core/widgets/app_tile.dart';
export 'package:lantern/core/widgets/base_screen.dart';
export 'package:lantern/core/widgets/bottomsheet.dart';
export 'package:lantern/core/widgets/custom_app_bar.dart';
export 'package:lantern/core/widgets/flag.dart';
// UI
export 'package:lantern/core/widgets/lantern_logo.dart';
export 'package:lantern/core/widgets/platform_card.dart';
export 'package:lantern/core/widgets/pro_banner.dart';
export 'package:lantern/core/widgets/pro_button.dart';
export 'package:lantern/features/home/data_usage.dart';

export '../../core/widgets/divider_space.dart';

AppRouter get appRouter => sl<AppRouter>();

String generatePassword() {
  const allChars =
      'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz0123456789!@#\$%^&*()-=+{};:,<.>/?';
  final random = Random.secure();
  return List.generate(8, (i) => allChars[random.nextInt(allChars.length)])
      .join();
}

bool isStoreVersion() {
  if (kDebugMode || AppBuildInfo.buildType == 'nightly') {
    final setting = sl<LocalStorageService>().getDeveloperSetting();
    if (setting != null) {
      return setting.testPlayPurchaseEnabled;
    }
    return !sl<StoreUtils>().isSideLoaded();
  }
  return !sl<StoreUtils>().isSideLoaded();
}

//copy to clipboard
void copyToClipboard(String text) {
  Clipboard.setData(ClipboardData(text: text));
}

Future<String> pasteFromClipboard() async {
  final data = await Clipboard.getData(Clipboard.kTextPlain);
  if (data != null && data.text != null) {
    return data.text!;
  } else {
    return '';
  }
}

/// Check user account status and updates user data if the user has a pro plan
Future<bool> checkUserAccountStatus(WidgetRef ref, BuildContext context) async {
  final delays = [Duration(seconds: 1), Duration(seconds: 2)];
  for (final delay in delays) {
    appLogger.info("Checking user account status with delay: $delay");
    if (delay != Duration.zero) await Future.delayed(delay);

    final result = await ref.read(lanternServiceProvider).fetchUserData();
    final isPro = result.fold(
      (failure) {
        appLogger.error("Failed to fetch user data: $failure");
        return false;
      },
      (newUser) {
        final isPro = newUser.legacyUserData.userLevel == 'pro';
        if (isPro) {
          // User has bought a plan
          // update user data
          appLogger.info("User is Pro: ${newUser.legacyUserData.email}");
          ref.read(homeProvider.notifier).updateUserData(newUser);
        }
        return isPro;
      },
    );

    if (isPro) return true; //Exit loop is found
  }
  return false;
}

void hideKeyboard() {
  FocusManager.instance.primaryFocus?.unfocus();
}

void sharePrivateAccessKey(
    PrivateServerEntity server, Map<String, dynamic> tokenPayload) {
  final expirationDate = tokenPayload['exp'].toString();
  final aliasName = tokenPayload['sub'];
  final uri = Uri(
    scheme: 'https',
    host: Uri.parse(AppUrls.lanternOfficial)
        .host, // ensures host is parsed correctly
    path: '/private-server',
    queryParameters: {
      'ip': server.externalIp,
      'port': server.port.toString(),
      'token': server.accessToken,
      'name': server.serverName,
      'exp': expirationDate,
      'alias': aliasName,
    },
  );
  final urlString = '${'join_my_private_server'.i18n} $uri';
  SharePlus.instance.share(ShareParams(text: urlString));
}

bool isSmallScreen(BuildContext context) {
  //Iphone 12 mini Size(375.0, 812.0)
  //Iphone 13      Size(390.0, 844.0)
  return MediaQuery.of(context).size.width <= 380;
}

String getReferralMessage(String planId) {
  final id = planId.split('-').first;
  if (id == '1m') {
    return 'referral_message_1m'.i18n;
  } else if (id == '1y') {
    return 'referral_message_1y'.i18n;
  } else if (id == '2y') {
    return 'referral_message_2y'.i18n;
  }
  return '';
}

/// Initial server location set to auto (fastest server)
ServerLocationEntity initialServerLocation() {
  return ServerLocationEntity(
    autoSelect: true,
    serverLocation: ''.i18n,
    serverName: '',
    serverType: ServerLocationType.auto.name,
    autoLocation: AutoLocationEntity(
      serverLocation: 'fastest_server'.i18n,
      serverName: '',
    ),
  );
}
