import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;

/// Country flag from an ISO 3166-1 alpha-2 code, rendered as a regional
/// indicator emoji by the system font (e.g. "IR" → 🇮🇷). Platforms that
/// drop part of the flag set (some de-Googled Android forks, vendor fonts
/// without TW) fall back to the two-letter glyphs.
///
/// On Windows the system emoji font (Segoe UI Emoji) does not paint regional
/// indicator pairs as flags, so we load a bundled Twemoji Mozilla font at
/// startup via [ensureFontLoaded] and route the [Text] through it.
class Flag extends StatelessWidget {
  final String countryCode;
  final Size size;

  const Flag({
    super.key,
    required this.countryCode,
    this.size = const Size(25, 18),
  });

  static const String _windowsEmojiFontFamily = 'Twemoji Mozilla';
  static bool _windowsEmojiFontLoaded = false;

  /// Registers the bundled flag-capable font on Windows. Safe to call from any
  /// platform — no-ops everywhere else. The asset is platform-scoped in
  /// pubspec.yaml so it is not shipped with the Android/iOS builds.
  static Future<void> ensureFontLoaded() async {
    if (!Platform.isWindows || _windowsEmojiFontLoaded) return;
    try {
      final loader = FontLoader(_windowsEmojiFontFamily)
        ..addFont(rootBundle.load('assets/fonts/TwemojiMozilla.ttf'));
      await loader.load();
      _windowsEmojiFontLoaded = true;
    } catch (_) {
      // Leave the flag as the regional-indicator fallback rather than crashing.
    }
  }

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
        clipBehavior: Clip.hardEdge,
        child: Text(
          _countryCodeToEmoji(countryCode),
          style: TextStyle(
            fontSize: size.height,
            fontFamily: Platform.isWindows ? _windowsEmojiFontFamily : null,
          ),
        ),
      ),
    );
  }
}
