import 'package:flutter/material.dart';

/// Country flag from an ISO 3166-1 alpha-2 code, rendered as a regional
/// indicator emoji by the system font (e.g. "IR" → 🇮🇷). Platforms that
/// drop part of the flag set (some de-Googled Android forks, vendor fonts
/// without TW) fall back to the two-letter glyphs.
class Flag extends StatelessWidget {
  final String countryCode;
  final Size size;

  const Flag({
    super.key,
    required this.countryCode,
    this.size = const Size(25, 18),
  });

  /// Returns 🏳️ for invalid input so a malformed code can't blow up the UI.
  static String _countryCodeToEmoji(String code) {
    if (code.length != 2) return '\u{1F3F3}\u{FE0F}'; // 🏳️
    final upper = code.toUpperCase();
    final first = upper.codeUnitAt(0);
    final second = upper.codeUnitAt(1);
    // Regional Indicator Symbol Letter A–Z = U+1F1E6..U+1F1FF.
    if (first < 0x41 || first > 0x5A || second < 0x41 || second > 0x5A) {
      return '\u{1F3F3}\u{FE0F}';
    }
    return String.fromCharCodes([
      0x1F1E6 + (first - 0x41),
      0x1F1E6 + (second - 0x41),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: size,
      child: FittedBox(
        // Normalize cross-platform glyph-height variance into the caller's box.
        fit: BoxFit.cover,
        child: Text(
          _countryCodeToEmoji(countryCode),
          style: TextStyle(fontSize: size.height),
        ),
      ),
    );
  }
}
