import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/vpn/macos_vision_smoke.dart';

void main() {
  Map<String, dynamic> server({
    String type = 'vless',
    String flow = 'xtls-rprx-vision',
    bool tls = true,
    bool insecure = false,
  }) => {
    'outbound': {
      'type': type,
      'flow': flow,
      'tls': {'enabled': tls, 'insecure': insecure},
    },
  };

  test('requires the parsed server to use Vision with TLS verification', () {
    expect(isVerifiedVisionServer(server()), isTrue);
    expect(isVerifiedVisionServer(server(type: 'trojan')), isFalse);
    expect(isVerifiedVisionServer(server(flow: '')), isFalse);
    expect(isVerifiedVisionServer(server(tls: false)), isFalse);
    expect(isVerifiedVisionServer(server(insecure: true)), isFalse);
    expect(isVerifiedVisionServer({'tag': 'vless-vision'}), isFalse);
  });

  final connection = <String, dynamic>{
    'inbound': 'tun/tun-in',
    'outbound': 'vless/test-server',
    'network': 'tcp',
    'domain': 'speed.cloudflare.com',
    'downlink': 8192,
  };

  test('accepts transferred bytes on the selected TUN outbound', () {
    expect(hasVisionTraffic([connection], 'test-server'), isTrue);
  });

  for (final replacement in [
    {'inbound': 'mixed/bypass-proxy'},
    {'outbound': 'direct/direct'},
    {'outbound': 'vless/another-server'},
    {'network': 'udp'},
    {'domain': 'unrelated.example'},
    {'downlink': 8191},
  ]) {
    test('rejects traffic with $replacement', () {
      expect(
        hasVisionTraffic([
          {...connection, ...replacement},
        ], 'test-server'),
        isFalse,
      );
    });
  }

  test('does not accept absent connection metadata', () {
    expect(hasVisionTraffic([], 'test-server'), isFalse);
    expect(hasVisionTraffic([{}], 'test-server'), isFalse);
  });
}
