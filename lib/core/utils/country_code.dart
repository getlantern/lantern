class CountryCode {
  static const censoredRegions = ['CN', 'RU', 'IR'];

  static String _current = '';
  static bool _isCensoredRegion = false;

  /// Latest country code received from core. Empty string until the first
  /// `country-code` event arrives (or when core sends an empty value).
  static String get current => _current;

  /// True once we've observed a censored country code from core, or when
  /// [markCensored] was called (e.g. Play Billing unreachable on Android).
  static bool get isCensoredRegion => _isCensoredRegion;

  static void update(String code) {
    _current = code;
    if (code.isNotEmpty && censoredRegions.contains(code.toUpperCase())) {
      _isCensoredRegion = true;
    }
  }

  /// Force-flag the current region as censored without a known country code.
  /// Used when Play Billing repeatedly fails on Android — a strong signal
  /// that the user is in a censored region even if the country lookup is
  /// blocked.
  static void markCensored() {
    _isCensoredRegion = true;
  }
}
