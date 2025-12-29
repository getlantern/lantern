import 'dart:math' as math;
import 'package:flutter/services.dart';

class ResellerCodeFormatter extends TextInputFormatter {
  static const _maxChars = 25;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.toUpperCase();

    // Count real chars (A-Z0-9) before cursor in the incoming value
    final cursor = math.max(0, newValue.selection.baseOffset);
    final rawBeforeCursor = raw.substring(0, math.min(cursor, raw.length));
    final realCharsBeforeCursor =
        RegExp(r'[A-Z0-9]').allMatches(rawBeforeCursor).length;

    // Clean + limit to 25 real chars
    final cleaned = raw.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final limited =
        cleaned.length > _maxChars ? cleaned.substring(0, _maxChars) : cleaned;

    // Format XXXXX-... every 5 chars
    final buffer = StringBuffer();
    for (var i = 0; i < limited.length; i++) {
      if (i > 0 && i % 5 == 0) buffer.write('-');
      buffer.write(limited[i]);
    }
    final formatted = buffer.toString();

    final clampedReal = math.min(realCharsBeforeCursor, limited.length);
    final hyphensBeforeCursor = clampedReal == 0 ? 0 : ((clampedReal - 1) ~/ 5);
    final newCursor =
        math.min(formatted.length, clampedReal + hyphensBeforeCursor);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursor),
      composing: TextRange.empty,
    );
  }
}
