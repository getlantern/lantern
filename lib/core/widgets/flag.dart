import 'package:flutter/material.dart';

/// Flag renders a country flag from a two-letter ISO 3166-1 alpha-2 code.
///
/// Uses Unicode regional indicator emoji (e.g. "IR" → 🇮🇷) — rendered by the
/// system emoji font, zero asset weight. Switched away from the
/// `country_flags` Dart package on 2026-05-15, which shipped pre-rasterized
/// vector flags totaling ~2.6 MB uncompressed (Serbia's coat of arms alone
/// was 513 KB). At our render size (24–30 px wide), the fine detail was
/// invisible anyway, and the bandwidth saving matters for Iranian sideload
/// users on constrained connections.
///
/// Behavior on platforms that don't carry the regional-indicator flag set
/// in their emoji font (some de-Googled Android forks, Chinese
/// vendor-customized fonts that drop the Taiwan flag): the text falls back
/// to the two letter glyphs (e.g. "IR") rendered with the emoji style.
/// Functional, less pretty — acceptable trade for the size cut.
class Flag extends StatelessWidget {
  final String countryCode;
  final Size size;

  const Flag({
    super.key,
    required this.countryCode,
    this.size = const Size(25, 18),
  });

  /// Converts an ISO 3166-1 alpha-2 country code into the corresponding
  /// regional indicator emoji sequence. Returns the white-flag emoji 🏳️
  /// for invalid input rather than throwing, so a malformed country code
  /// in the location list doesn't blow up the UI.
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
        // BoxFit.contain keeps the emoji aspect ratio inside the requested
        // box. The system emoji font draws regional-indicator pairs at the
        // requested fontSize but the actual rendered glyph height varies
        // across Android versions; FittedBox normalizes that to the size
        // the caller asked for.
        fit: BoxFit.contain,
        child: Text(
          _countryCodeToEmoji(countryCode),
          style: TextStyle(fontSize: size.height),
        ),
      ),
    );
  }
}
