import 'dart:math' as math;

import 'package:flutter/services.dart';

const _licenseMarker = 'PRO';
const _licenseKeyLength = 25;

String _cleanKey(String key) =>
    key.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

/// Website license keys carry a PRO prefix or suffix (PRO-XXXXX-...).
/// Key characters never include O, so reseller codes cannot match.
bool isWebLicenseKey(String key) {
  final cleaned = _cleanKey(key);
  return cleaned.length > _licenseMarker.length &&
      (cleaned.startsWith(_licenseMarker) || cleaned.endsWith(_licenseMarker));
}

/// The code part of [key]: upper case A-Z0-9 without the PRO marker,
/// at most 25 characters.
String licenseKeyCode(String key) {
  var cleaned = _cleanKey(key);
  if (isWebLicenseKey(key)) {
    cleaned = cleaned.startsWith(_licenseMarker)
        ? cleaned.substring(_licenseMarker.length)
        : cleaned.substring(0, cleaned.length - _licenseMarker.length);
  }
  return cleaned.length > _licenseKeyLength
      ? cleaned.substring(0, _licenseKeyLength)
      : cleaned;
}

/// Whether [key] holds a full 25-character code, with or without the marker.
bool isCompleteLicenseKey(String key) {
  final expected = isWebLicenseKey(key)
      ? _licenseKeyLength + _licenseMarker.length
      : _licenseKeyLength;
  return _cleanKey(key).length == expected;
}

/// A "P" or "PR" typed after a full code: kept so the suffix can be typed.
String _partialSuffix(String key) {
  final cleaned = _cleanKey(key);
  if (isWebLicenseKey(key) || cleaned.length <= _licenseKeyLength) return '';
  final extra = cleaned.substring(_licenseKeyLength);
  return _licenseMarker.startsWith(extra) ? extra : '';
}

/// Formats [key] as XXXXX-XXXXX-XXXXX-XXXXX-XXXXX, keeping a PRO prefix or
/// suffix as its own group.
String formatLicenseKey(String key) {
  final groups = RegExp(
    r'.{1,5}',
  ).allMatches(licenseKeyCode(key)).map((m) => m[0]).join('-');
  if (!isWebLicenseKey(key)) {
    final partial = _partialSuffix(key);
    return partial.isEmpty ? groups : '$groups-$partial';
  }
  return _cleanKey(key).startsWith(_licenseMarker)
      ? '$_licenseMarker-$groups'
      : '$groups-$_licenseMarker';
}

class ResellerCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.toUpperCase();
    final cursor = math.max(0, newValue.selection.baseOffset);
    final realCharsBeforeCursor = RegExp(
      r'[A-Z0-9]',
    ).allMatches(raw.substring(0, math.min(cursor, raw.length))).length;

    final formatted = formatLicenseKey(raw);

    // Put the cursor right after the same number of real characters.
    var newCursor = formatted.length;
    var seen = 0;
    for (var i = 0; i < formatted.length; i++) {
      if (seen == realCharsBeforeCursor) {
        newCursor = i;
        break;
      }
      if (formatted[i] != '-') seen++;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursor),
      composing: TextRange.empty,
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final upperText = newValue.text.toUpperCase();

    return newValue.copyWith(
      text: upperText,
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}
