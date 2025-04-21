// Captlize
extension CapExtension on String {
  String get capitalize => this[0].toUpperCase() + substring(1);
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
      'Contains special character': password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')),
    };
  }


}
