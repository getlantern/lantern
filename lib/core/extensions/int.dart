extension ByteConversion on int {
  /// Converts bytes to megabytes (MB)
  double get toMB => this / 1e6;

  /// Human-readable size in SI (powers of 1000) units, e.g. "1.2 GB".
  /// One decimal below 10 units, none above.
  String get siBytes {
    const units = ['B', 'kB', 'MB', 'GB', 'TB', 'PB'];
    if (this < 1000) return '${this < 0 ? 0 : this} B';
    var value = toDouble();
    var unit = 0;
    while (value >= 999.5 && unit < units.length - 1) {
      value /= 1000;
      unit++;
    }
    final text = value < 9.95
        ? value.toStringAsFixed(1)
        : value.toStringAsFixed(0);
    return '$text ${units[unit]}';
  }
}
