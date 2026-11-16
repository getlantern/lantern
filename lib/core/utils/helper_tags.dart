/// Helper outbound tags are client-side pseudonyms for the user's helper
/// pairings, and a line naming a helper outbound may carry the helper's
/// address. The spec forbids exporting either, so the app never shows helper
/// outbounds as servers and redacts both from its logs. This is a port of
/// radiance's internal/redact.Helper (with lantern-box's RedactHelperTags) and
/// must stay in step with it.
const redactedAddress = '<redacted>';

// A helper tag inside longer text. There is no trailing word boundary, so a
// suffix such as "_failed" does not shield a tag.
final _helperTag = RegExp(r'\bhelper-[0-9a-f]{12}');

// Text that may name a helper outbound: a helper tag, or the word "helper"
// a redaction left in its place ("outbound/samizdat[helper]",
// "outbound/helper[samizdat]", "helper_failed", ...).
final _helperNamed = RegExp(r'\bhelper(?:\b|_)');

// Text that may be an IP address, with or without a port: a bracketed host,
// or a run of hex digits, dots and colons. Each match is checked before it is
// replaced.
final _ipCandidate = RegExp(
  r'\[[0-9A-Fa-f:.]+(?:%[0-9A-Za-z_.\-]+)?\](?::[0-9]{1,5})?|[0-9A-Fa-f]*[.:][0-9A-Fa-f.:]*(?:%[0-9A-Za-z_.\-]+)?',
);

bool isHelperTag(String tag) => tag.startsWith('helper-');

/// radiance's url-test group over every helper outbound (vpn.PersonalProxiesTag).
/// Selecting it connects through the user's personal proxies. It marks the
/// device as having them, so it is redacted like a helper tag.
const personalProxiesTag = 'personal-proxies';

/// radiance's url-test group over one friend's outbounds (vpn.PersonalProxyTag).
/// It is never selected by itself: [personalProxySelection] selects one
/// friend through it. Redacted like [personalProxiesTag].
const personalProxyTag = 'personal-proxy';

/// The tag that selects the friend whose outbound tag is [friendTag] as the
/// personal proxy (radiance's vpn.PersonalProxySelection).
String personalProxySelection(String friendTag) =>
    '$personalProxyTag:$friendTag';

/// The friend's outbound tag that [tag] selects, or null when [tag] is not a
/// [personalProxySelection] (radiance's vpn.ParsePersonalProxySelection).
String? personalProxyFriend(String tag) {
  const prefix = '$personalProxyTag:';
  if (!tag.startsWith(prefix)) return null;
  final friend = tag.substring(prefix.length);
  return _wholeHelperTag.hasMatch(friend) ? friend : null;
}

final _wholeHelperTag = RegExp(r'^helper-[0-9a-f]{12}$');

/// Whether [tag] is the personal proxies group or one friend's selection:
/// never listed as a server, since each has its own row.
bool isPersonalProxyGroup(String tag) =>
    tag == personalProxiesTag || tag.startsWith('$personalProxyTag:');

// The app's ServerLocationType.personalProxy as it appears in log lines
// ("type=personalProxy"). It reveals the same thing as the group tag.
final _personalProxyType = RegExp(r'\bpersonalProxy\b');

bool _namesHelper(String s) =>
    s.contains(personalProxiesTag) ||
    s.contains(personalProxyTag) ||
    (s.contains('personalProxy') && _personalProxyType.hasMatch(s)) ||
    (s.contains('helper') && _helperNamed.hasMatch(s));

/// Replaces each helper tag with "helper" and, on every line that names a
/// helper outbound, every IP address (with any port) with [redactedAddress].
/// Lines that name no helper outbound keep their addresses.
String redactHelperTags(String text) {
  if (!_namesHelper(text)) return text;
  final redacted = text
      .split('\n')
      .map(
        (line) => _namesHelper(line)
            ? line.replaceAllMapped(_ipCandidate, (m) => _redactIp(m[0]!))
            : line,
      )
      .join('\n');
  return redacted
      .replaceAll(_helperTag, 'helper')
      .replaceAll(personalProxiesTag, 'helper')
      .replaceAll(personalProxyTag, 'helper')
      .replaceAll(_personalProxyType, 'helper');
}

// The candidate can take in dots and colons from the surrounding text on
// either side, so try m whole and then from just after each dot or colon,
// leftmost first so the longest address wins.
String _redactIp(String m) {
  for (var start = 0; start < m.length; start++) {
    if (start > 0 && m[start - 1] != '.' && m[start - 1] != ':') continue;
    final r = _redactTrailing(m.substring(start));
    if (r != null) return m.substring(0, start) + r;
  }
  return m;
}

// Checks m whole, then with one trailing dot or colon at a time set aside.
String? _redactTrailing(String m) {
  for (
    var core = m;
    core.isNotEmpty;
    core = core.substring(0, core.length - 1)
  ) {
    if (_isIpAddr(core)) return redactedAddress + m.substring(core.length);
    final last = core[core.length - 1];
    if (last != '.' && last != ':') return null;
  }
  return null;
}

// Whether s is an IP address, optionally bracketed, zoned or followed by a
// port, as radiance's isIPAddr decides it.
bool _isIpAddr(String s) {
  if (s.startsWith('[')) {
    final end = s.indexOf(']');
    return end >= 0 && _parseIp(s.substring(1, end));
  }
  if (_parseIp(s)) return true;
  // net.SplitHostPort without brackets: the port follows the last colon and
  // the host may not contain one.
  final i = s.lastIndexOf(':');
  if (i < 0) return false;
  final host = s.substring(0, i);
  final port = s.substring(i + 1);
  return !host.contains(':') && port.isNotEmpty && _parseIp(host);
}

bool _parseIp(String s) {
  final zone = s.indexOf('%');
  if (zone >= 0) s = s.substring(0, zone);
  return _goParseIp(s);
}

// Go's net.ParseIP (netip.ParseAddr without a zone).
bool _goParseIp(String s) {
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (c == '.') return _parseIPv4(s);
    if (c == ':') return _parseIPv6(s);
    if (c == '%') return false;
  }
  return false;
}

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

int _hexVal(int c) {
  if (_isDigit(c)) return c - 0x30;
  if (c >= 0x61 && c <= 0x66) return c - 0x61 + 10;
  if (c >= 0x41 && c <= 0x46) return c - 0x41 + 10;
  return -1;
}

bool _parseIPv4(String s) {
  var val = 0, pos = 0, digLen = 0;
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (_isDigit(c)) {
      if (digLen == 1 && val == 0) return false;
      val = val * 10 + c - 0x30;
      digLen++;
      if (val > 255) return false;
    } else if (c == 0x2e) {
      if (i == 0 || i == s.length - 1 || s.codeUnitAt(i - 1) == 0x2e) {
        return false;
      }
      if (pos == 3) return false;
      pos++;
      val = 0;
      digLen = 0;
    } else {
      return false;
    }
  }
  return pos == 3;
}

bool _parseIPv6(String input) {
  if (input.contains('%')) return false;
  var s = input;
  var ellipsis = -1;
  if (s.length >= 2 && s[0] == ':' && s[1] == ':') {
    ellipsis = 0;
    s = s.substring(2);
    if (s.isEmpty) return true;
  }
  var i = 0;
  while (i < 16) {
    var off = 0;
    var acc = 0;
    for (; off < s.length; off++) {
      final v = _hexVal(s.codeUnitAt(off));
      if (v < 0) break;
      acc = (acc << 4) + v;
      if (off > 3) return false;
      if (acc > 0xffff) return false;
    }
    if (off == 0) return false;
    if (off < s.length && s[off] == '.') {
      if (ellipsis < 0 && i != 12) return false;
      if (i + 4 > 16) return false;
      if (!_parseIPv4(s)) return false;
      s = '';
      i += 4;
      break;
    }
    i += 2;
    s = s.substring(off);
    if (s.isEmpty) break;
    if (s[0] != ':') return false;
    if (s.length == 1) return false;
    s = s.substring(1);
    if (s[0] == ':') {
      if (ellipsis >= 0) return false;
      ellipsis = i;
      s = s.substring(1);
      if (s.isEmpty) break;
    }
  }
  if (s.isNotEmpty) return false;
  if (i < 16) return ellipsis >= 0;
  return ellipsis < 0;
}
