// Captlize
import 'package:email_validator/email_validator.dart';

extension CapExtension on String {
  String get capitalize => this[0].toUpperCase() + substring(1);
}


extension EmailValidation on String {
  bool isValidEmail() {
  return EmailValidator.validate(this);
  }
}



extension PasswordValidations on String {
  bool isPasswordValid() {
    trim(); // Remove spaces at the start and end
    bool has6Characters = length >= 8;
    bool hasUppercase = contains(RegExp(r'[A-Z]'));
    bool hasLowercase = contains(RegExp(r'[a-z]'));
    bool hasNumber = contains(RegExp(r'[0-9]'));
    bool hasSpecialCharacter = contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    return has6Characters &&
        hasUppercase &&
        hasLowercase &&
        hasNumber &&
        hasSpecialCharacter;
  }
}