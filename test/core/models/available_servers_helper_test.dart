import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/utils/helper_tags.dart';

Map<String, dynamic> _server(String tag) => {
  'tag': tag,
  'type': 'samizdat',
  'isLantern': true,
  'location': {'country': 'Germany', 'city': 'Berlin', 'country_code': 'DE'},
};

void main() {
  test('the personal proxies group is never listed as a server', () {
    final servers = AvailableServers.fromJson([
      _server('lantern-1'),
      _server(personalProxiesTag),
      {..._server(personalProxiesTag), 'isLantern': false},
    ]);
    expect(servers.lanternServers.map((s) => s.tag), ['lantern-1']);
    expect(servers.userServers, isEmpty);
    expect(servers.hasUserServers, isFalse);
  });

  test('helper outbounds are never listed as Lantern servers', () {
    final servers = AvailableServers.fromJson([
      _server('lantern-1'),
      _server('helper-0123456789ab'),
    ]);
    expect(servers.lanternServers.map((s) => s.tag), ['lantern-1']);
    expect(
      servers.lanternServerLocations.map((s) => s.tag),
      isNot(contains('helper-0123456789ab')),
    );
  });

  test('redactHelperTags replaces every helper tag', () {
    expect(
      redactHelperTags(
        'outbound/samizdat[helper-0123456789ab] and helper-ffffffffffff',
      ),
      'outbound/samizdat[helper] and helper',
    );
    expect(redactHelperTags('helper-short stays'), 'helper-short stays');
    expect(isHelperTag('helper-0123456789ab'), isTrue);
    expect(isHelperTag('lantern-1'), isFalse);
  });

  // The same cases as radiance's internal/redact tests.
  const tag = 'helper-0123456789ab';
  final cases = {
    'outbound/samizdat[$tag]: dial tcp 203.0.113.7:443: i/o timeout':
        'outbound/samizdat[helper]: dial tcp <redacted>: i/o timeout',
    'outbound/samizdat[$tag]: no route to 203.0.113.7.':
        'outbound/samizdat[helper]: no route to <redacted>.',
    'outbound/samizdat[$tag]: dial tcp [2001:db8::7]:8443: refused':
        'outbound/samizdat[helper]: dial tcp <redacted>: refused',
    'outbound/samizdat[$tag]: unreachable 2001:db8::7':
        'outbound/samizdat[helper]: unreachable <redacted>',
    '${tag}_failed: dial tcp 203.0.113.7:443':
        'helper_failed: dial tcp <redacted>',
    'msg="dial tcp 203.0.113.7:443: refused" tag=outbound/helper[samizdat]':
        'msg="dial tcp <redacted>: refused" tag=outbound/helper[samizdat]',
    'msg="handshake with [2001:db8::7]:51820 failed" tag=endpoint/helper[wireguard]':
        'msg="handshake with <redacted> failed" tag=endpoint/helper[wireguard]',
    'outbound attempt failed outbound helper attempt 1 error dial tcp 203.0.113.7:443':
        'outbound attempt failed outbound helper attempt 1 error dial tcp <redacted>',
    'helper_failed: dial tcp 203.0.113.7:443':
        'helper_failed: dial tcp <redacted>',
    'helper peer:203.0.113.7:443 refused': 'helper peer:<redacted> refused',
    'helper peer:2001:db8::7 refused': 'helper peer:<redacted> refused',
    'helper dial [::1]:443 and ::1': 'helper dial <redacted> and <redacted>',
    'outbound/samizdat[helper]: dial tcp 203.0.113.7:443':
        'outbound/samizdat[helper]: dial tcp <redacted>',
    'time="2026-10-23 13:30:00.000 UTC" msg="outbound/samizdat[$tag]: dial tcp 203.0.113.7:443"':
        'time="2026-10-23 13:30:00.000 UTC" msg="outbound/samizdat[helper]: dial tcp <redacted>"',
  };
  cases.forEach((input, want) {
    test('redacts the address on a helper line: $want', () {
      expect(redactHelperTags(input), want);
    });
  });

  // radiance's TestHelperRedactsEveryIPv6Form.
  const pre = 'outbound/samizdat[$tag]: ';
  const forms = {
    'dial ::1': 'dial <redacted>',
    'dial fe80::': 'dial <redacted>',
    'dial 2001:db8::': 'dial <redacted>',
    'dial 2001:db8:1234::': 'dial <redacted>',
    'no route to 2001:db8::.': 'no route to <redacted>.',
    'dial tcp [2001:db8::]:443': 'dial tcp <redacted>',
    'dial tcp [fe80::1%eth0]:443': 'dial tcp <redacted>',
    'dial fe80::1%eth0, retrying': 'dial <redacted>, retrying',
    'dial (2001:db8::7); retrying': 'dial (<redacted>); retrying',
    'dial 203.0.113.7: refused': 'dial <redacted>: refused',
    'at 12:34:56 and 13:30:00.000, step 1.2':
        'at 12:34:56 and 13:30:00.000, step 1.2',
    'code dead:beef ok': 'code dead:beef ok',
  };
  forms.forEach((input, want) {
    test('redacts every IPv6 form: $input', () {
      expect(redactHelperTags(pre + input), 'outbound/samizdat[helper]: $want');
    });
  });

  test('lines that name no helper keep their addresses', () {
    const input =
        'outbound/samizdat[lantern-1]: dial tcp 198.51.100.9:443\n'
        'outbound/samizdat[$tag]: dial tcp 203.0.113.7:443\n'
        'dial tcp [2001:db8::9]:443 ok\n';
    const want =
        'outbound/samizdat[lantern-1]: dial tcp 198.51.100.9:443\n'
        'outbound/samizdat[helper]: dial tcp <redacted>\n'
        'dial tcp [2001:db8::9]:443 ok\n';
    expect(redactHelperTags(input), want);
    expect(
      redactHelperTags('nothing to see 198.51.100.9'),
      'nothing to see 198.51.100.9',
    );
  });

  test('redactHelperTags redacts the personal proxies group tag', () {
    expect(
      redactHelperTags(
        'Connecting to server: personalProxy with tag: personal-proxies',
      ),
      'Connecting to server: helper with tag: helper',
    );
    expect(
      redactHelperTags(
        'outbound/mutableurltest[personal-proxies]: dial tcp 203.0.113.7:443',
      ),
      'outbound/mutableurltest[helper]: dial tcp <redacted>',
    );
  });

  test('redactHelperTags redacts the personalProxy location type', () {
    expect(
      redactHelperTags('updateServerLocation: type=personalProxy name=x'),
      'updateServerLocation: type=helper name=x',
    );
    expect(
      redactHelperTags('{serverType: personalProxy, via 203.0.113.7:443}'),
      '{serverType: helper, via <redacted>}',
    );
    expect(
      redactHelperTags('personalProxyBanner shown'),
      'personalProxyBanner shown',
    );
  });
}
