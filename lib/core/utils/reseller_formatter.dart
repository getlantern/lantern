// ignore_for_file: use_build_context_synchronously

import 'package:flutter/services.dart';

class ResellerCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue value,
  ) {
    final newValue = value.text;
    var formattedValue = '';

    for (var i = 0; i < newValue.length; i++) {
      if (newValue[i] != '-') formattedValue += newValue[i];
      var index = i + 1;
      var dashIndex = index == 5 || index == 11 || index == 17 || index == 23;
      if (dashIndex &&
          index != newValue.length &&
          !(formattedValue.endsWith('-'))) {
        formattedValue += '-';
      }
    }
    return value.copyWith(
      text: formattedValue,
      selection: TextSelection.fromPosition(
        TextPosition(offset: formattedValue.length),
      ),
    );
  }
}
