class CountryCode {
  static const censoredRegions = ['CN', 'RU', 'IR'];

  /// Countries where the app never starts sharing for a helper approval on
  /// its own. Mirrors `censoredCountries` in lantern-cloud
  /// `regions/regions.go` exactly; keep the two in step. Wider than
  /// [censoredRegions], which other features use.
  static const helperCensoredCountries = {
    'AE', 'AF', 'AZ', 'BY', 'CN', 'CU', 'EG', 'ET', 'IR', 'KP', //
    'MM', 'PK', 'RU', 'SA', 'SY', 'TJ', 'TM', 'UZ', 'VN', 'YE',
  };

  static String _current = '';

  /// Latest country code received from core. Empty string until the first
  /// `country-code` event arrives (or when core sends an empty value).
  static String get current => _current;
  static bool get isKnown => _current.isNotEmpty;

  static void update(String code) {
    _current = code.trim().toUpperCase();
  }
}

/// Whether sharing may start on its own for a helper approval in [country]:
/// only when it is known and not censored. A client-side backstop to
/// lantern-cloud's IP-geolocation guard, which can fail open.
bool helperAutoStartAllowed(String country) {
  final c = country.trim().toUpperCase();
  return c.isNotEmpty && !CountryCode.helperCensoredCountries.contains(c);
}
