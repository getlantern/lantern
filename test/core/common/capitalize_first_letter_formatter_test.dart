import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/app_text_field.dart';

void main() {
  const formatter = CapitalizeFirstLetterFormatter();

  TextEditingValue format(TextEditingValue value) =>
      formatter.formatEditUpdate(TextEditingValue.empty, value);

  test('capitalizes the first letter of committed text', () {
    final result = format(const TextEditingValue(text: 'ali'));
    expect(result.text, 'Ali');
  });

  test('leaves text alone while the IME is composing', () {
    const composing = TextEditingValue(
      text: 'ni',
      selection: TextSelection.collapsed(offset: 2),
      composing: TextRange(start: 0, end: 2),
    );
    expect(format(composing), composing);
  });

  test('capitalizes once the composition is committed', () {
    final result = format(
      const TextEditingValue(
        text: 'nina',
        selection: TextSelection.collapsed(offset: 4),
      ),
    );
    expect(result.text, 'Nina');
  });
}
