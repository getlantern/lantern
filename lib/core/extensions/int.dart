extension ByteConversion on int {
  /// Converts bytes to megabytes (MB)
  double get toMB => this / 1e6;
}
