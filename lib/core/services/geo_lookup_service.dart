import 'dart:convert';

import 'package:flutter_earth_globe/globe_coordinates.dart';
import 'package:http/http.dart' as http;

/// Result of a peer geo lookup. Country/flag default to empty when the
/// lookup fails; coordinates default to a centre-of-the-globe sentinel.
class PeerGeo {
  const PeerGeo({
    required this.coordinates,
    required this.countryName,
    required this.countryCode,
    required this.flagEmoji,
  });

  final GlobeCoordinates coordinates;
  final String countryName;
  final String countryCode;
  final String flagEmoji;

  static const unknown = PeerGeo(
    coordinates: GlobeCoordinates(0, 0),
    countryName: '',
    countryCode: '',
    flagEmoji: '',
  );
}

class GeoLookupService {
  static const _selfUrl = 'https://geo.getiantem.org';
  // ipwho.is: HTTPS, no auth, 10k req/month free. Returns country + lat/lon
  // + flag emoji in one shot.
  static const _peerUrl = 'https://ipwho.is';

  // Per-IP cache for peerLookup. Most connections are short-lived
  // liveness probes from the same handful of client IPs, so without a
  // cache an active SmC peer would issue hundreds of ipwho.is requests
  // per minute — chewing through the 10k/month free quota and leaking
  // more data to the third party than necessary. Cached entries
  // (including the PeerGeo.unknown sentinel from a failed lookup) live
  // for the rest of the process — IP→country bindings don't change on
  // human timescales, and the alternative TTL bookkeeping adds
  // complexity without changing the privacy or quota math.
  static final Map<String, PeerGeo> _peerCache = {};

  /// Test-only: drop the cache. Production code does not call this.
  static void resetCacheForTest() => _peerCache.clear();

  // ISO country code → approximate centre coordinates. Used as a fallback
  // when ipwho.is doesn't return city-level coords.
  static const _countryCenters = {
    'AF': (lat: 33.0, lng: 65.0),
    'AL': (lat: 41.0, lng: 20.0),
    'DZ': (lat: 28.0, lng: 3.0),
    'AD': (lat: 42.5, lng: 1.6),
    'AO': (lat: -12.5, lng: 18.5),
    'AR': (lat: -34.0, lng: -64.0),
    'AM': (lat: 40.0, lng: 45.0),
    'AU': (lat: -27.0, lng: 133.0),
    'AT': (lat: 47.33, lng: 13.33),
    'AZ': (lat: 40.5, lng: 47.5),
    'BD': (lat: 24.0, lng: 90.0),
    'BY': (lat: 53.0, lng: 28.0),
    'BE': (lat: 50.83, lng: 4.0),
    'BJ': (lat: 9.5, lng: 2.25),
    'BO': (lat: -17.0, lng: -65.0),
    'BA': (lat: 44.0, lng: 18.0),
    'BR': (lat: -10.0, lng: -55.0),
    'BG': (lat: 43.0, lng: 25.0),
    'KH': (lat: 13.0, lng: 105.0),
    'CM': (lat: 6.0, lng: 12.0),
    'CA': (lat: 60.0, lng: -95.0),
    'CL': (lat: -30.0, lng: -71.0),
    'CN': (lat: 35.0, lng: 105.0),
    'CO': (lat: 4.0, lng: -72.0),
    'CD': (lat: 0.0, lng: 25.0),
    'CR': (lat: 10.0, lng: -84.0),
    'HR': (lat: 45.17, lng: 15.5),
    'CU': (lat: 21.5, lng: -80.0),
    'CZ': (lat: 49.75, lng: 15.5),
    'DK': (lat: 56.0, lng: 10.0),
    'DO': (lat: 19.0, lng: -70.67),
    'EC': (lat: -2.0, lng: -77.5),
    'EG': (lat: 27.0, lng: 30.0),
    'SV': (lat: 13.83, lng: -88.92),
    'EE': (lat: 59.0, lng: 26.0),
    'ET': (lat: 8.0, lng: 38.0),
    'FI': (lat: 64.0, lng: 26.0),
    'FR': (lat: 46.0, lng: 2.0),
    'GE': (lat: 42.0, lng: 43.5),
    'DE': (lat: 51.0, lng: 9.0),
    'GH': (lat: 8.0, lng: -2.0),
    'GR': (lat: 39.0, lng: 22.0),
    'GT': (lat: 15.5, lng: -90.25),
    'HN': (lat: 15.0, lng: -86.5),
    'HK': (lat: 22.25, lng: 114.17),
    'HU': (lat: 47.0, lng: 20.0),
    'IS': (lat: 65.0, lng: -18.0),
    'IN': (lat: 20.0, lng: 77.0),
    'ID': (lat: -5.0, lng: 120.0),
    'IR': (lat: 32.0, lng: 53.0),
    'IQ': (lat: 33.0, lng: 44.0),
    'IE': (lat: 53.0, lng: -8.0),
    'IL': (lat: 31.5, lng: 34.75),
    'IT': (lat: 42.83, lng: 12.83),
    'CI': (lat: 8.0, lng: -5.0),
    'JP': (lat: 36.0, lng: 138.0),
    'JO': (lat: 31.0, lng: 36.0),
    'KZ': (lat: 48.0, lng: 68.0),
    'KE': (lat: 1.0, lng: 38.0),
    'KR': (lat: 37.0, lng: 127.5),
    'KW': (lat: 29.34, lng: 47.66),
    'KG': (lat: 41.0, lng: 75.0),
    'LA': (lat: 18.0, lng: 105.0),
    'LV': (lat: 57.0, lng: 25.0),
    'LB': (lat: 33.83, lng: 35.83),
    'LT': (lat: 56.0, lng: 24.0),
    'MG': (lat: -20.0, lng: 47.0),
    'MY': (lat: 2.5, lng: 112.5),
    'ML': (lat: 17.0, lng: -4.0),
    'MX': (lat: 23.0, lng: -102.0),
    'MD': (lat: 47.0, lng: 29.0),
    'MN': (lat: 46.0, lng: 105.0),
    'MA': (lat: 32.0, lng: -5.0),
    'MZ': (lat: -18.25, lng: 35.0),
    'MM': (lat: 22.0, lng: 98.0),
    'NP': (lat: 28.0, lng: 84.0),
    'NL': (lat: 52.5, lng: 5.75),
    'NZ': (lat: -41.0, lng: 174.0),
    'NI': (lat: 13.0, lng: -85.0),
    'NG': (lat: 10.0, lng: 8.0),
    'NO': (lat: 62.0, lng: 10.0),
    'OM': (lat: 21.0, lng: 57.0),
    'PK': (lat: 30.0, lng: 70.0),
    'PA': (lat: 9.0, lng: -80.0),
    'PY': (lat: -23.0, lng: -58.0),
    'PE': (lat: -10.0, lng: -76.0),
    'PH': (lat: 13.0, lng: 122.0),
    'PL': (lat: 52.0, lng: 20.0),
    'PT': (lat: 39.5, lng: -8.0),
    'QA': (lat: 25.5, lng: 51.25),
    'RO': (lat: 46.0, lng: 25.0),
    'RU': (lat: 60.0, lng: 100.0),
    'SA': (lat: 25.0, lng: 45.0),
    'SN': (lat: 14.0, lng: -14.0),
    'RS': (lat: 44.0, lng: 21.0),
    'SG': (lat: 1.37, lng: 103.8),
    'SK': (lat: 48.67, lng: 19.5),
    'SI': (lat: 46.0, lng: 15.0),
    'ZA': (lat: -29.0, lng: 24.0),
    'ES': (lat: 40.0, lng: -4.0),
    'LK': (lat: 7.0, lng: 81.0),
    'SE': (lat: 62.0, lng: 15.0),
    'CH': (lat: 47.0, lng: 8.0),
    'SY': (lat: 35.0, lng: 38.0),
    'TW': (lat: 23.5, lng: 121.0),
    'TJ': (lat: 39.0, lng: 71.0),
    'TZ': (lat: -6.0, lng: 35.0),
    'TH': (lat: 15.0, lng: 100.0),
    'TN': (lat: 34.0, lng: 9.0),
    'TR': (lat: 39.0, lng: 35.0),
    'TM': (lat: 40.0, lng: 60.0),
    'UA': (lat: 49.0, lng: 32.0),
    'AE': (lat: 24.0, lng: 54.0),
    'GB': (lat: 54.0, lng: -2.0),
    'US': (lat: 38.0, lng: -97.0),
    'UY': (lat: -33.0, lng: -56.0),
    'UZ': (lat: 41.0, lng: 64.0),
    'VE': (lat: 8.0, lng: -66.0),
    'VN': (lat: 16.0, lng: 106.0),
    'YE': (lat: 15.0, lng: 48.0),
    'ZM': (lat: -15.0, lng: 30.0),
    'ZW': (lat: -20.0, lng: 30.0),
  };

  static GlobeCoordinates _isoToCoords(String iso) {
    final c = _countryCenters[iso] ?? _countryCenters['US']!;
    return GlobeCoordinates(c.lat, c.lng);
  }

  /// Looks up the current device's location (no IP argument). Prefers the
  /// precise Location lat/lon the geo service returns, falling back to the
  /// country centre, then the US centre on any failure.
  static Future<GlobeCoordinates> selfLookup() async {
    try {
      // The geo service answers on /lookup; the bare root 404s. Hitting the
      // root meant every donor's origin silently fell through to the US-centre
      // fallback below regardless of where they actually were.
      final response = await http
          .get(Uri.parse('$_selfUrl/lookup'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        // Precise device coordinates when present — so the origin point sits
        // on the user's actual location, not the centre of their country.
        final loc = data['Location'] as Map<String, dynamic>?;
        final lat = (loc?['Latitude'] as num?)?.toDouble();
        final lng = (loc?['Longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          return GlobeCoordinates(lat, lng);
        }
        final iso =
            (data['Country'] as Map<String, dynamic>?)?['IsoCode'] as String? ??
            'US';
        return _isoToCoords(iso);
      }
    } catch (_) {}
    return _isoToCoords('US');
  }

  /// Looks up country, flag, and coordinates for a peer [ip] address.
  /// Returns [PeerGeo.unknown] on any failure so callers can suppress the
  /// arc / banner rather than displaying a wrong country.
  ///
  /// Privacy note: each call ships [ip] — the address of a peer routing
  /// through this user's Share My Connection inbound — to ipwho.is, a
  /// third-party geo-IP service. For most SmC consumers these are
  /// censored users' addresses, so this is an outbound data flow to a
  /// non-Lantern endpoint. Current rationale for accepting it: the IP
  /// is already public-by-virtue-of-being-a-TCP-source-addr the host
  /// observes, ipwho.is doesn't tie lookups to the caller, and the
  /// alternative — relaying through Lantern's own infrastructure or
  /// shipping a MaxMind DB with the app — is meaningful additional
  /// scope. Move this to a Lantern-controlled endpoint or a local DB
  /// before any production-scale rollout where peer protection matters
  /// beyond demo use.
  static Future<PeerGeo> peerLookup(String ip) async {
    // Cache hit: short-circuit before any network I/O. Also caches
    // PeerGeo.unknown so a previously-failed lookup doesn't retry on
    // every subsequent probe from the same IP.
    final cached = _peerCache[ip];
    if (cached != null) return cached;
    PeerGeo result = PeerGeo.unknown;
    try {
      final response = await http
          .get(Uri.parse('$_peerUrl/$ip'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final iso = (data['country_code'] as String?) ?? '';
          final lat = (data['latitude'] as num?)?.toDouble();
          final lng = (data['longitude'] as num?)?.toDouble();
          final coords = (lat != null && lng != null)
              ? GlobeCoordinates(lat, lng)
              : _isoToCoords(iso);
          final flagObj = data['flag'] as Map<String, dynamic>?;
          result = PeerGeo(
            coordinates: coords,
            countryName: (data['country'] as String?) ?? '',
            countryCode: iso,
            flagEmoji: (flagObj?['emoji'] as String?) ?? '',
          );
        }
      }
    } catch (_) {}
    _peerCache[ip] = result;
    return result;
  }
}
