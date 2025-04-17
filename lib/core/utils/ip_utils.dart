import 'dart:convert';
import 'package:http/http.dart' as http;

class IPUtils {
  static Future<String?> getUserCountry() async {
    try {
      final response = await http.get(Uri.parse('https://ipinfo.io/json'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['country'];
      }
    } catch (e) {
      print('Failed to get user location: $e');
    }
    return null;
  }
}
