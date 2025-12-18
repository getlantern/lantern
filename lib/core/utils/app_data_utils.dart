import 'dart:convert';
import 'dart:typed_data';

Uint8List? iconToBytes(Object? v) {
  if (v == null) return null;

  if (v is Uint8List) return v;

  if (v is List<int>) {
    // Already typed; just need to wrap it
    return Uint8List.fromList(v);
  }

  if (v is List) {
    // dynamic list coming from JSON/platform channel
    final out = <int>[];
    for (final e in v) {
      if (e is int) out.add(e);
    }
    return out.isEmpty ? null : Uint8List.fromList(out);
  }

  if (v is String) return _decodeIconString(v);

  return null;
}

Uint8List? _decodeIconString(String s) {
  s = s.trim();
  if (s.isEmpty) return null;

  final comma = s.lastIndexOf(',');
  if (comma != -1) s = s.substring(comma + 1);

  // Remove whitespace/newlines
  s = s.replaceAll(RegExp(r'\s+'), '');

  final looksUrlSafe = s.contains('-') || s.contains('_');
  if (looksUrlSafe) {
    s = s.replaceAll('-', '+').replaceAll('_', '/');
  }

  // Add missing padding if needed
  final mod = s.length % 4;
  if (mod != 0) s = s.padRight(s.length + (4 - mod), '=');

  try {
    return base64Decode(s);
  } catch (_) {
    return null;
  }
}
