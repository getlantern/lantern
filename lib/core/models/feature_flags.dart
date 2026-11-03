enum FeatureFlag {
  privateGcp('private.gcp'),
  metrics('otel.metrics'),
  traces('otel.traces'),
  autoUpdateEnabled('autoUpdateEnabled'),
  androidSideloadAutoUpdateEnabled('androidSideloadAutoUpdateEnabled'),
  // Server-side gate for the inviter's side of helper invites ("Get help
  // from a friend"). lantern-cloud sets it for the pilot's inviters only.
  // Volunteers are never flagged: their screens show through an invite link
  // or a pairing (lantern-cloud lets them through without the flag).
  helperInvites('helper_invites'),
  // Server-side gate for the entire Unbounded / Share My Connection
  // surface. When false (the default for censored regions), the
  // Unbounded tab, settings entry, project link, and auto-enable hooks
  // all disappear — censored users should never see a "share your
  // connection" UI that could draw attention to them on-device. Mirrors
  // radiance/unbounded/unbounded.go shouldRunUnbounded, which already
  // gates execution on the same Features[UNBOUNDED] flag.
  unbounded('unbounded');

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
