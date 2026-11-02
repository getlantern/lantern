/// What lantern-core's helper engine reports (lantern-core/helper View).
/// Parsed tolerantly: an entry of the wrong shape is skipped, and a field of
/// the wrong type falls back to its default.
class HelpersView {
  const HelpersView({
    this.unlocked = false,
    this.myName = '',
    this.invites = const [],
    this.claims = const [],
    this.helpers = const [],
    this.helping = const [],
    this.activity,
    this.newHelping = false,
  });

  final bool unlocked;
  final String myName;
  final List<HelperInviteView> invites;
  final List<HelperClaimView> claims;
  final List<HelperPairingView> helpers;
  final List<HelperPairingView> helping;
  final HelperActivity? activity;
  final bool newHelping;

  /// Something is waiting on the other person: poll for it.
  bool get needsPolling => invites.isNotEmpty || claims.isNotEmpty;

  /// The first invite a friend has claimed: it waits on this user to
  /// compare codes and approve.
  HelperInviteView? get awaitingApproval =>
      invites.where((i) => i.claimed).firstOrNull;

  /// The friend helping this device whose outbound tag is [outboundTag].
  HelperPairingView? helperByTag(String outboundTag) => outboundTag.isEmpty
      ? null
      : helpers.where((h) => h.outboundTag == outboundTag).firstOrNull;

  /// Claims whose code the volunteer can still show the inviter: sent (not
  /// provisional) and unexpired at [nowUnix].
  Iterable<HelperClaimView> waitingClaims(int nowUnix) => claims.where(
    (c) => c.code.isNotEmpty && !c.provisional && c.expiresUnix > nowUnix,
  );

  factory HelpersView.fromJson(Map<String, dynamic> j) => HelpersView(
    unlocked: j['unlocked'] == true,
    myName: _str(j['my_name']),
    invites: _list(j['invites'], HelperInviteView.fromJson),
    claims: _list(j['claims'], HelperClaimView.fromJson),
    helpers: _list(j['helpers'], HelperPairingView.fromJson),
    helping: _list(j['helping'], HelperPairingView.fromJson),
    activity: j['activity'] is Map<String, dynamic>
        ? HelperActivity.fromJson(j['activity'] as Map<String, dynamic>)
        : null,
    newHelping: j['new_helping'] == true,
  );
}

class HelperInviteView {
  const HelperInviteView({
    required this.id,
    required this.state,
    this.link = '',
    this.expiresUnix = 0,
    this.code = '',
    this.volunteerName = '',
    this.inviterName = '',
  });

  final String id;
  final String state;
  final String link;
  final int expiresUnix;
  final String code;
  final String volunteerName;

  /// The name this user gave with this invite.
  final String inviterName;

  bool get claimed => state == 'claimed';

  /// An unclaimed invite past its expiry. Its link no longer works, so it is
  /// not shown. A claimed invite stays, so the inviter can still decide it.
  bool get expired =>
      !claimed &&
      expiresUnix > 0 &&
      expiresUnix <= DateTime.now().millisecondsSinceEpoch ~/ 1000;

  factory HelperInviteView.fromJson(Map<String, dynamic> j) => HelperInviteView(
    id: _str(j['id']),
    state: _str(j['state']),
    link: _str(j['link']),
    expiresUnix: _int(j['expires_unix']),
    code: _str(j['code']),
    volunteerName: _str(j['volunteer_name']),
    inviterName: _str(j['inviter_name']),
  );
}

class HelperClaimView {
  const HelperClaimView({
    required this.id,
    required this.code,
    this.expiresUnix = 0,
    this.provisional = false,
  });

  final String id;
  final String code;
  final int expiresUnix;

  /// Not yet known to have reached the inviter: claiming the link again
  /// retries it.
  final bool provisional;

  factory HelperClaimView.fromJson(Map<String, dynamic> j) => HelperClaimView(
    id: _str(j['id']),
    code: _str(j['code']),
    expiresUnix: _int(j['expires_unix']),
    provisional: j['provisional'] == true,
  );
}

class HelperPairingView {
  const HelperPairingView({
    required this.pairingId,
    this.name = '',
    this.online = false,
    this.sinceUnix = 0,
    this.connected,
    this.outboundTag = '',
  });

  final String pairingId;
  final String name;
  final bool online;
  final int sinceUnix;

  /// On a pairing in which this device is helped: the friend's outbound tag,
  /// which selects them on their own. Empty until lantern-cloud gives it.
  final String outboundTag;

  /// On a pairing this device helps: whether that friend routes through this
  /// device right now. Null until the engine reports it, and then nothing
  /// may claim either way.
  final bool? connected;

  /// Whether this friend can be selected on their own: lantern-cloud gave
  /// their outbound tag and says they are online, and radiance has a live
  /// route to them. [status] is radiance's status by outbound tag, null while
  /// unknown (the VPN is off, or radiance did not answer): online then
  /// decides alone.
  bool selectable(Map<String, PersonalProxyStatus>? status) {
    if (outboundTag.isEmpty || !online) return false;
    if (status == null) return true;
    return status[outboundTag]?.live ?? false;
  }

  factory HelperPairingView.fromJson(Map<String, dynamic> j) =>
      HelperPairingView(
        pairingId: _str(j['pairing_id']),
        name: _str(j['name']),
        online: j['online'] == true,
        sinceUnix: _int(j['since_unix']),
        connected: j['connected'] is bool ? j['connected'] as bool : null,
        outboundTag: _str(j['outbound_tag']),
      );
}

/// radiance's status of one friend this device invited (lantern-core's
/// personal_proxy_status op).
class PersonalProxyStatus {
  const PersonalProxyStatus({this.direct = false, this.rooms = false});

  /// The config carries the friend's direct outbound.
  final bool direct;

  /// This device can reach the friend through Unbounded's rooms.
  final bool rooms;

  /// The friend's group has a member to route through.
  bool get live => direct || rooms;

  /// The op's answer, by outbound tag. Entries without a tag are skipped.
  static Map<String, PersonalProxyStatus> parseAll(Map<String, dynamic> j) {
    final out = <String, PersonalProxyStatus>{};
    final list = j['statuses'];
    if (list is! List) return out;
    for (final e in list) {
      if (e is! Map<String, dynamic>) continue;
      final tag = _str(e['tag']);
      if (tag.isEmpty) continue;
      out[tag] = PersonalProxyStatus(
        direct: e['direct'] == true,
        rooms: e['rooms'] == true,
      );
    }
    return out;
  }
}

class HelperActivity {
  const HelperActivity({
    this.day = '',
    this.activeSeconds = 0,
    this.relayedBytes = 0,
  });

  final String day;
  final int activeSeconds;
  final int relayedBytes;

  factory HelperActivity.fromJson(Map<String, dynamic> j) => HelperActivity(
    day: _str(j['day']),
    activeSeconds: _int(j['active_seconds']),
    relayedBytes: _int(j['relayed_bytes']),
  );
}

String _str(Object? v) => v is String ? v : '';

int _int(Object? v) => switch (v) {
  int i => i,
  num n => n.toInt(),
  String s => int.tryParse(s) ?? 0,
  _ => 0,
};

List<T> _list<T>(Object? v, T Function(Map<String, dynamic>) parse) {
  if (v is! List) return const [];
  final out = <T>[];
  for (final e in v) {
    if (e is! Map<String, dynamic>) continue;
    try {
      out.add(parse(e));
    } catch (_) {
      // One malformed entry must not hide the others.
    }
  }
  return out;
}
