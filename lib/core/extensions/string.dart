// Captlize
extension CapExtension on String {
  String get capitalize => this[0].toUpperCase() + substring(1);
}
