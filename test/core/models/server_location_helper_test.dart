import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/models/server_location.dart';

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
}
