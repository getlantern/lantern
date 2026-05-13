import 'dart:convert';

import 'package:http/http.dart' as http;

class IPUtils {
  // List of countries where the app is censored
  static final censoredRegion = ['CN', 'RU', 'IR'];
  static String cacheCountry = '';

  /// Sync flag set once getUserCountry() confirms the user is in a censored
  /// region. Read by isStoreVersion() so Play-Store builds fall back to the
  /// Stripe flow where Google Play Billing is unreachable.
  static bool isCensoredRegion = false;

  static Future<String?> getUserCountry() async {
    try {
      if (cacheCountry != '') {
        return cacheCountry;
      }
      final response = await http.get(Uri.parse('https://ipinfo.io/json'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        cacheCountry = data['country'] ?? '';
        final country = data['country'].toString();

        if (censoredRegion.contains(country.toUpperCase())) {
          isCensoredRegion = true;
        }
        return country;
      }
    } catch (e) {
      print('Failed to get user location: $e');
    }
    return null;
  }
}
