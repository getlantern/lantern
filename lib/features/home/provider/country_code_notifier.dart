import 'dart:ui';

import 'package:lantern/core/utils/country_code.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/services/logger_service.dart';

part 'country_code_notifier.g.dart';

@Riverpod(keepAlive: true)
class CountryCodeNotifier extends _$CountryCodeNotifier {
  @override
  String build() {
    /// Seed with the system locale's country as a best-effort guess.
    final initial =
        PlatformDispatcher.instance.locale.countryCode?.toUpperCase() ?? '';
    if (initial.isNotEmpty) {
      appLogger.debug('Seeding country code from system locale: $initial');
      CountryCode.update(initial);
    }
    return initial;
  }

  void update(String code) {
    appLogger.debug('Updating country code to: $code');
    CountryCode.update(code);
    state = code;
  }
}
