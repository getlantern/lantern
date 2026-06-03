import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/extensions/string.dart';

void main() {
  group('String.isValidEmail()', () {
    test('accepts a normal address', () {
      expect('3563246481zp@gmail.com'.isValidEmail(), isTrue);
    });

    test('trims leading/trailing whitespace from a paste', () {
      expect('  good@gmail.com  '.isValidEmail(), isTrue);
      expect('good@gmail.com '.isValidEmail(), isTrue); // trailing nbsp
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
      expect('$base $m'.isValidEmail(), isFalse); // no-break space
      expect('$base​$m'.isValidEmail(), isFalse); // zero-width space
      expect('$base‌$m'.isValidEmail(), isFalse); // ZWNJ
      expect('$base‍$m'.isValidEmail(), isFalse); // ZWJ
      expect('$base⁠$m'.isValidEmail(), isFalse); // word joiner
      expect('$base　$m'.isValidEmail(), isFalse); // ideographic space
      expect('$base­$m'.isValidEmail(), isFalse); // soft hyphen
    });
  });
}
