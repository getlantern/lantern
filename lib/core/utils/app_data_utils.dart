import 'dart:convert';
import 'dart:typed_data';

Uint8List? iconToBytes(dynamic v) {
  if (v == null) return null;

  if (v is Uint8List) return v;

  if (v is List<int>) return Uint8List.fromList(v);

  if (v is List) {
    return Uint8List.fromList(v.cast<int>());
  }

  if (v is String) {
    if (v.isEmpty) return null;

    final s = v.contains(',') ? v.split(',').last : v;
    final cleaned = s.replaceAll(RegExp(r'\s'), '');

    // Fix missing padding (if necessary)
    final padded = cleaned.padRight(((cleaned.length + 3) ~/ 4) * 4, '=');

    try {
      return base64Decode(padded);
    } catch (_) {
      try {
        return base64Url.decode(padded);
      } catch (_) {
        return null;
      }
    }
  }

  return null;
}
