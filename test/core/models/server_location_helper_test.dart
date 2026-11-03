import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/core/utils/helper_tags.dart';

Server _server(String tag) => Server.fromJson({
  'tag': tag,
  'type': 'samizdat',
  'isLantern': true,
  'location': {'country': 'Germany', 'city': 'Berlin', 'country_code': 'DE'},
});

void main() {
  test('an auto-selected Lantern server shows its location', () {
    final loc = ServerLocation.autoSelected(_server('samizdat-1'));
    expect(loc.serverType, ServerLocationType.auto.name);
    expect(loc.city, 'Berlin');
    expect(loc.autoLocation!.displayName, 'Germany - Berlin');
    expect(loc.autoLocation!.countryCode, 'DE');
    expect(loc.autoLocation!.country, 'Germany');
    expect(loc.autoLocation!.protocol, 'samizdat');
  });

  test('an auto-selected helper outbound never shows where the helper is', () {
    final loc = ServerLocation.autoSelected(_server('helper-0123456789ab'));
    expect(loc.serverType, ServerLocationType.auto.name);
    expect(loc.city, isEmpty);
    expect(loc.country, isEmpty);
    expect(loc.countryCode, isEmpty);
    expect(loc.autoLocation!.displayName, 'fastest_server'.i18n);
    expect(loc.autoLocation!.country, isEmpty);
    expect(loc.autoLocation!.countryCode, isEmpty);
    expect(loc.autoLocation!.protocol, isEmpty);
    final json = loc.toJson().toString();
    expect(json, isNot(contains('Berlin')));
    expect(json, isNot(contains('Germany')));
  });

  test('the personal proxies location shows no place', () {
    final loc = ServerLocation.personalProxy();
    expect(loc.serverType, ServerLocationType.personalProxy.name);
    expect(loc.serverName, personalProxiesTag);
    expect(
      loc.serverType.toServerLocationType,
      ServerLocationType.personalProxy,
    );
    expect(loc.country, isEmpty);
    expect(loc.city, isEmpty);
    expect(loc.countryCode, isEmpty);
    expect(loc.protocol, isEmpty);
  });

  test('a selected server maps to its location type', () {
    Server s(String tag, bool lantern) => Server.fromJson({
      'tag': tag,
      'type': 'mutableurltest',
      'isLantern': lantern,
      'location': {'country': '', 'city': '', 'country_code': ''},
    });
    expect(
      ServerLocation.selected(s(personalProxiesTag, false)).serverType,
      ServerLocationType.personalProxy.name,
    );
    expect(
      ServerLocation.selected(s('lantern-1', true)).serverType,
      ServerLocationType.lanternLocation.name,
    );
    expect(
      ServerLocation.selected(s('my-vps', false)).serverType,
      ServerLocationType.privateServer.name,
    );
  });

  test('a stored personal proxy location gets the current label', () {
    final stored = ServerLocation.personalProxy()
        .copyWith(displayName: 'Something Else')
        .toJsonString();
    final loc = ServerLocation.fromJsonString(stored);
    expect(loc.serverType, ServerLocationType.personalProxy.name);
    expect(loc.serverName, personalProxiesTag);
    expect(loc.displayName, 'personal_proxy'.i18n);
  });

  test('a stored personal proxy location keeps its Smart Location', () {
    final stored = ServerLocation.personalProxy()
        .copyWith(
          autoLocation: const AutoLocation(
            country: 'Germany',
            countryCode: 'DE',
            displayName: 'Germany - Berlin',
          ),
        )
        .toJsonString();
    final loc = ServerLocation.fromJsonString(stored);
    expect(loc.autoLocation!.displayName, 'Germany - Berlin');
  });

  test('the log form of a personal proxy location hides its label', () {
    final log = ServerLocation.personalProxy().toLogJson().toString();
    expect(log, isNot(contains('personal_proxy'.i18n)));
    expect(
      ServerLocation.personalProxy().toJson()['serverType'],
      'personalProxy',
    );
    expect(
      ServerLocation.fromServer(
        server: _server('samizdat-1'),
      ).toLogJson()['displayName'],
      'Germany - Berlin',
    );
  });

  group('one friend selected', () {
    const friend = 'helper-0123456789ab';

    test('selects by its selection tag and shows no place or name', () {
      final loc = ServerLocation.personalProxy(friendTag: friend);
      expect(loc.serverType, ServerLocationType.personalProxy.name);
      expect(loc.serverName, personalProxySelection(friend));
      expect(loc.personalProxyFriendTag, friend);
      expect(loc.displayName, 'personal_proxy'.i18n);
      expect(loc.countryCode, isEmpty);
      expect(loc.city, isEmpty);
      expect(ServerLocation.personalProxy().personalProxyFriendTag, isNull);
    });

    test("radiance's selection maps back to the friend", () {
      final loc = ServerLocation.selected(
        Server.fromJson({
          'tag': personalProxySelection(friend),
          'type': 'mutableurltest',
          'isLantern': false,
          'location': {'country': '', 'city': '', 'country_code': ''},
        }),
      );
      expect(loc.serverType, ServerLocationType.personalProxy.name);
      expect(loc.personalProxyFriendTag, friend);
    });

    test('survives storage, and only a well-formed tag does', () {
      final loc = ServerLocation.fromJsonString(
        ServerLocation.personalProxy(friendTag: friend).toJsonString(),
      );
      expect(loc.personalProxyFriendTag, friend);
      final bad = ServerLocation.fromJsonString(
        ServerLocation.personalProxy()
            .copyWith(serverName: 'personal-proxy:not-a-tag')
            .toJsonString(),
      );
      expect(bad.serverName, personalProxiesTag);
    });

    test('a non-personal-proxy location never has a friend', () {
      final loc = ServerLocation(
        serverName: personalProxySelection(friend),
        serverType: ServerLocationType.privateServer.name,
      );
      expect(loc.personalProxyFriendTag, isNull);
    });
  });
}
