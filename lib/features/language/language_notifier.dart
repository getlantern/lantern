import 'dart:ui';

import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/services/logger_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'language_notifier.g.dart';

@Riverpod(keepAlive: true)
class LanguageNotifier extends _$LanguageNotifier {
  @override
  Locale build() {
    final Locale locale = _loadLanguage() ?? _useDeviceLocal();
    state = locale;
    return locale;
  }

  Locale? _loadLanguage() {
    final local = AppDB.get<String>('local');
    // if local found use user selected language
    if (local != null) {
      appLogger.debug("Language loaded from local storage $local");
      return Locale(local.split('_').first, local.split('_').last);
    }
    return null;
  }

  Locale _useDeviceLocal() {
    // user is first time use device local
    final deviceLocale = PlatformDispatcher.instance.locale;

    // if device local start with en then use en_US
    if (deviceLocale.toString().startsWith('en')) {
      final Locale enUS = Locale('en', 'US');
      AppDB.set<String>('local', enUS.toString());
      appLogger.debug("Device locale ${enUS.toString()}");
      return enUS;
    }
    AppDB.set<String>('local', deviceLocale.toString());
    appLogger.debug("Device locale ${deviceLocale.toString()}");
    return deviceLocale;
  }

  void changeLanguage(Locale locale) {
    final oldLocale = AppDB.get<String>('local');
    if (oldLocale == locale.toString()) return;
    state = locale;
    AppDB.set<String>('local', locale.toString());
  }
}
