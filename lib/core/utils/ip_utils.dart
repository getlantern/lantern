import 'dart:convert';
import 'package:http/http.dart' as http;

class IPUtils {

  // List of countries where the app is censored
 static final censoredRegion= ['CN', 'RU', 'IR','IN'];
 static String cacheCountry='';

  static Future<String?> getUserCountry() async {
    try {
      if(cacheCountry!= ''){
        return cacheCountry;
      }
      final response = await http.get(Uri.parse('https://ipinfo.io/json'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        cacheCountry = data['country'] ?? '';
        return data['country'];
      }
    } catch (e) {
      print('Failed to get user location: $e');
    }
    return null;
  }
}
