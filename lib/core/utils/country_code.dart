class CountryCode {
  static const censoredRegions = ['CN', 'RU', 'IR'];

  static String _current = '';

  /// Latest country code received from core. Empty string until the first
  /// `country-code` event arrives (or when core sends an empty value).
  static String get current => _current;
  static bool get isKnown => _current.isNotEmpty;

  /// True when core reports a censored country.
  static bool get isCensoredRegion => censoredRegions.contains(_current);

  static void update(String code) {
    _current = code.trim().toUpperCase();
  }
}
