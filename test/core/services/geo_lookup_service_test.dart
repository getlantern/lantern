import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lantern/core/services/geo_lookup_service.dart';

void main() {
  setUp(GeoLookupService.resetCacheForTest);

  test('concurrent peer lookups for one IP share a request', () async {
    var requests = 0;
    final results = await http.runWithClient(
      () {
        return Future.wait([
          GeoLookupService.peerLookup('192.0.2.1'),
          GeoLookupService.peerLookup('192.0.2.1'),
        ]);
      },
      () => MockClient((request) async {
        requests++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return http.Response(
          jsonEncode({
            'Country': {
              'IsoCode': 'US',
              'Names': {'en': 'United States'},
            },
          }),
          200,
        );
      }),
    );
    expect(requests, 1);
    expect(results.map((g) => g.countryCode), ['US', 'US']);
    // Later calls hit the cache.
    await GeoLookupService.peerLookup('192.0.2.1');
    expect(requests, 1);
  });
}
