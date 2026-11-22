import 'package:lantern/core/models/feature_flags.dart';

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
/// only when it is known and not censored. Only [helperVolunteerAllowed]'s
/// fallback for a server that does not send helper_volunteer.
bool helperAutoStartAllowed(String country) {
  final c = country.trim().toUpperCase();
  return c.isNotEmpty && !CountryCode.helperCensoredCountries.contains(c);
}

/// Whether this device may volunteer as a Personal Proxy, given the config's
/// [flags]. lantern-cloud decides it (Features["helper_volunteer"]). Before a
/// config arrives, or from a server that does not send the flag, it falls
/// back to [helperAutoStartAllowed], which is false until the country is
/// known.
bool helperVolunteerAllowed(Map<String, dynamic> flags, String country) {
  if (flags.containsKey(FeatureFlag.helperVolunteer.key)) {
    return flags.getBool(FeatureFlag.helperVolunteer);
  }
  return helperAutoStartAllowed(country);
}
