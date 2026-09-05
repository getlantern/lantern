import 'dart:async';

class CountryCode {
  static const censoredRegions = ['CN', 'RU', 'IR'];

  static String _current = '';
  static final _knownCompleter = Completer<void>();

  /// Latest country code received from core. Empty string until the first
  /// `country-code` event arrives (or when core sends an empty value).
  static String get current => _current;
  static bool get isKnown => _current.isNotEmpty;

  /// True when core reports a censored country.
  static bool get isCensoredRegion => censoredRegions.contains(_current);

  static void update(String code) {
    _current = code.trim().toUpperCase();
    if (isKnown && !_knownCompleter.isCompleted) {
      _knownCompleter.complete();
    }
  }

  static Future<bool> waitUntilKnown({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (isKnown) {
      return true;
    }
    try {
      await _knownCompleter.future.timeout(timeout);
    } catch (_) {
      // The caller decides how to proceed when config country is unavailable.
    }
    return isKnown;
  }
}
