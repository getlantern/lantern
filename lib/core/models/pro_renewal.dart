/// Escalating renewal states for one-time Pro purchases (engineering#3845).
/// Computed from the total access end date (`expiration`, which the server
/// derives including bonus time), never from the paid expiration alone.
enum ProRenewalState {
  /// Pro with more than a week left, an auto-renewing subscription, or not a
  /// Pro user — no banner.
  none,

  /// 7 to 1 days of access left — amber banner.
  withinWeek,

  /// Last day of access — red banner.
  expiresToday,

  /// Access has ended — red banner.
  expired,
}

class ProRenewalInfo {
  final ProRenewalState state;

  /// Local date the user's access ends (or ended). Null when [state] is
  /// [ProRenewalState.none].
  final DateTime? accessEndDate;

  /// Calendar days from today until [accessEndDate]. 0 on the last day,
  /// negative once expired.
  final int daysLeft;

  const ProRenewalInfo(this.state, this.accessEndDate, this.daysLeft);

  static const none = ProRenewalInfo(ProRenewalState.none, null, 0);
}
