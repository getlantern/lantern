import 'package:lantern/core/utils/country_code.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/services/logger_service.dart';

part 'country_code_notifier.g.dart';

@Riverpod(keepAlive: true)
class CountryCodeNotifier extends _$CountryCodeNotifier {
  @override
  String build() {
    return '';
  }

  void update(String code) {
    appLogger.debug('Updating country code to: $code');
    CountryCode.update(code);
    state = code;
  }
}
