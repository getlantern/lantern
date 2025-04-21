// Captlize
import 'dart:ffi';
import 'dart:ffi' as ffi;

import 'package:email_validator/email_validator.dart';
import 'package:ffi/ffi.dart';

extension CapExtension on String {
  String get capitalize => this[0].toUpperCase() + substring(1);
}

extension EmailValidation on String {
  bool isValidEmail() {
    return EmailValidator.validate(this);
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
