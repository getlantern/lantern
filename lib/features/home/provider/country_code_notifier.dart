import 'package:lantern/core/utils/country_code.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/services/logger_service.dart';

part 'country_code_notifier.g.dart';

@Riverpod(keepAlive: true)
class CountryCodeNotifier extends _$CountryCodeNotifier {
  @override
  String build() {
    return CountryCode.current;
  }

  void update(String code) {
    CountryCode.update(code);
    state = CountryCode.current;
    appLogger.debug('Updating country code to: $state');
  }
}
