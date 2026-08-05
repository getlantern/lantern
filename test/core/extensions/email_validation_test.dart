import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/extensions/string.dart';

void main() {
  group('String.isValidEmail()', () {
    // Invisible code points that copy-paste can inject between visible
    // characters. Declared as \u escapes (not literal glyphs) so the test stays
    // readable in review and is not altered by editors/formatters that
    // normalize or strip invisible characters.
    const noBreakSpace = '\u00A0';
    const zeroWidthSpace = '\u200B';
    const zeroWidthNonJoiner = '\u200C';
    const zeroWidthJoiner = '\u200D';
    const wordJoiner = '\u2060';
    const ideographicSpace = '\u3000';
    const softHyphen = '\u00AD';

    test('accepts a normal address', () {
      expect('3563246481zp@gmail.com'.isValidEmail(), isTrue);
    });

    test('trims leading/trailing whitespace from a paste', () {
      expect('  good@gmail.com  '.isValidEmail(), isTrue);
      expect('good@gmail.com$noBreakSpace'.isValidEmail(), isTrue);
    });

    test('keeps genuine international addresses valid', () {
      expect('测试@例子.中国'.isValidEmail(), isTrue);
    });

    test('rejects empty / whitespace-only', () {
      expect(''.isValidEmail(), isFalse);
      expect('   '.isValidEmail(), isFalse);
    });

    test('rejects a plain internal ASCII space', () {
      expect('3563246481zp@gmail.co m'.isValidEmail(), isFalse);
    });

    test('rejects hidden/zero-width characters from copy-paste', () {
      const base = '3563246481zp@gmail.co';
      const m = 'm';
      expect('$base$noBreakSpace$m'.isValidEmail(), isFalse);
      expect('$base$zeroWidthSpace$m'.isValidEmail(), isFalse);
      expect('$base$zeroWidthNonJoiner$m'.isValidEmail(), isFalse);
      expect('$base$zeroWidthJoiner$m'.isValidEmail(), isFalse);
      expect('$base$wordJoiner$m'.isValidEmail(), isFalse);
      expect('$base$ideographicSpace$m'.isValidEmail(), isFalse);
      expect('$base$softHyphen$m'.isValidEmail(), isFalse);
    });
  });
}
