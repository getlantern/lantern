import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;

/// Country flag from an ISO 3166-1 alpha-2 code. On Windows we route the
/// Text through a bundled Twemoji Mozilla font because Segoe UI Emoji has no
/// flag-sequence ligatures.
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

  /// Windows-only; load .ttf is platform-scoped
  static Future<void> ensureFontLoaded() async {
    if (!Platform.isWindows || _windowsEmojiFontLoaded) return;
    try {
      final loader = FontLoader(_windowsEmojiFontFamily)
        ..addFont(rootBundle.load('assets/fonts/TwemojiMozilla.ttf'));
      await loader.load();
      _windowsEmojiFontLoaded = true;
    } catch (_) {}
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
            fontFamily: Platform.isWindows && _windowsEmojiFontLoaded
                ? _windowsEmojiFontFamily
                : null,
          ),
        ),
      ),
    );
  }
}
