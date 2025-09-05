enum FeatureFlag {
  sentry('sentry'),
  privateGcp('private.gcp'),
  autoUpdateEnabled('autoUpdateEnabled');

  final String key;
  const FeatureFlag(this.key);
}

extension FeatureMapX on Map<String, dynamic> {
  bool getBool(FeatureFlag flag, {bool defaultValue = false}) {
    final v = this[flag.key];
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase();
      if (s == 'true' || s == '1' || s == 'yes') return true;
      if (s == 'false' || s == '0' || s == 'no') return false;
    }
    return defaultValue;
  }
}
