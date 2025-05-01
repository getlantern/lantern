import 'dart:convert';

class JwtToken{


  static Map<String, dynamic> decodeToken(String token) {
    final splitToken = token.split(".");
    if (splitToken.length != 3) {
      throw FormatException('Invalid token');
    }
    try {
      final payloadBase64 = splitToken[1]; // Payload is always the index 1
      // Base64 should be multiple of 4. Normalize the payload before decode it
      final normalizedPayload = base64.normalize(payloadBase64);
      // Decode payload, the result is a String
      final payloadString = utf8.decode(base64.decode(normalizedPayload));
      // Parse the String to a Map<String, dynamic>
      final decodedPayload = jsonDecode(payloadString);
  // Return the decoded payload
      return decodedPayload;
    } catch (error) {
      throw FormatException('Invalid payload');
    }
  }
}