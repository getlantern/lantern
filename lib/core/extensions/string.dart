// Captlize
import 'dart:ffi' as ffi;
import 'dart:ffi';

import 'package:email_validator/email_validator.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';

final regex = RegExp(r'.+? - (.+?) \[[A-Z]{2}\]');

extension CapExtension on String {
  String get capitalize => isEmpty ? '' : this[0].toUpperCase() + substring(1);
}

extension EmailValidation on String {
  bool isValidEmail() {
    return EmailValidator.validate(this);
  }
}

extension IsoDateFormatter on String {
  String toMMDDYYDate() {
    try {
      final dateTime = DateTime.parse(this).toLocal();
      final mm = dateTime.month.toString().padLeft(2, '0');
      final dd = dateTime.day.toString().padLeft(2, '0');
      final yy = (dateTime.year % 100).toString().padLeft(2, '0');
      return "$mm/$dd/$yy";
    } catch (_) {
      return this; // return original string if parsing fails
    }
  }
}

extension PasswordValidations on String {
  Map<String, bool> getValidationResults() => validatePassword(this);

  bool isPasswordValid() => getValidationResults().values.every((v) => v);

  Map<String, bool> validatePassword(String password) {
    password = password.trim();

    return {
      'At least 8 characters': password.length >= 8,
      'Contains uppercase letter': password.contains(RegExp(r'[A-Z]')),
      'Contains lowercase letter': password.contains(RegExp(r'[a-z]')),
      'Contains number': password.contains(RegExp(r'[0-9]')),
      'Contains special character':
          password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')),
    };
  }
}

extension FFIExtension on String {
  Pointer<ffi.Char> get toCharPtr {
    return toNativeUtf8().cast<Char>();
  }
}

extension LocalizationExtension on String {
  Locale get toLocale {
    final spilt = split('_');
    return Locale(
      spilt[0],
      spilt.length > 1 ? spilt[1] : '',
    );
  }
}

extension LocationParsing on String {
  /// Extracts the readable city name (e.g., "New York City")
  String get locationName {
    if (isEmpty) return '';
    final match = regex.firstMatch(this);
    final rawName = match?.group(1) ?? '';
    final name = rawName
        .split('-')
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
    return '$countryCode-$name';
  }

  String get countryCode {
    final regex = RegExp(r'\[([A-Z]{2})\]');
    final match = regex.firstMatch(this);
    return match?.group(1) ?? '';
  }
}

extension StringCasingExtension on String {
  String toTitleCase() {
    if (isEmpty) return this;
    return split(' ')
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');
  }
}
