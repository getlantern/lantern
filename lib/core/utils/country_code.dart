class CountryCode {
  static const censoredRegions = ['CN', 'RU', 'IR'];

  static String _current = '';
  static bool _playBillingFallback = false;

  /// Latest country code received from core. Empty string until the first
  /// `country-code` event arrives (or when core sends an empty value).
  static String get current => _current;

  /// True when core reports a censored country or Play Billing has failed
  /// enough times that the app should offer the non-store payment path.
  static bool get isCensoredRegion =>
      censoredRegions.contains(_current) || _playBillingFallback;

  static void update(String code) {
    _current = code.trim().toUpperCase();
  }

  /// Force-flag the current region as censored without a known country code.
  /// Used when Play Billing repeatedly fails on Android — a strong signal
  /// that the user is in a censored region even if the country lookup is
  /// blocked.
  static void markCensored() {
    _playBillingFallback = true;
  }
}
