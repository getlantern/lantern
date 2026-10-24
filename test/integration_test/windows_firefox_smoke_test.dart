import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/vpn/windows_firefox_smoke.dart';

void main() {
  test('accepts only an IPv4 response from the browser', () {
    expect(firefoxProbeAddress('203.0.113.4\n'), '203.0.113.4');
    for (final value in [null, 42, '::1', '', '<html>offline</html>']) {
      expect(() => firefoxProbeAddress(value), throwsFormatException);
    }
  });

  test('WebDriver is restricted to IPv4 loopback', () {
    for (final endpoint in [
      'https://127.0.0.1:4444/',
      'http://192.0.2.1:4444/',
      'http://localhost:4444/',
    ]) {
      expect(() => FirefoxWebDriver(Uri.parse(endpoint)), throwsArgumentError);
    }
  });

  test('WebDriver uses W3C JSON commands and rejects errors', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final driver = FirefoxWebDriver(
      Uri.parse('http://127.0.0.1:${server.port}/'),
    );
    addTearDown(driver.close);
    final requests = <String>[];
    server.listen((request) async {
      requests.add('${request.method} ${request.uri.path}');
      expect(request.headers.contentType?.mimeType, 'application/json');
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == '/session') {
        expect(jsonDecode(await utf8.decoder.bind(request).join()), {
          'test': 1,
        });
        request.response.write(
          jsonEncode({
            'value': {'sessionId': 'owned'},
          }),
        );
      } else {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.write(
          jsonEncode({
            'value': {'error': 'invalid session'},
          }),
        );
      }
      await request.response.close();
    });
    expect(await driver.command('POST', 'session', {'test': 1}), {
      'sessionId': 'owned',
    });
    await expectLater(
      driver.command('DELETE', 'session/missing'),
      throwsStateError,
    );
    expect(requests, ['POST /session', 'DELETE /session/missing']);
  });

  test('WebDriver commands cannot escape the local driver endpoint', () async {
    final driver = FirefoxWebDriver(Uri.parse('http://127.0.0.1:4444/'));
    addTearDown(driver.close);
    await expectLater(
      driver.command('GET', 'http://192.0.2.1/session'),
      throwsArgumentError,
    );
  });

  test('preserves independent socket ownership in evidence', () {
    final connection = {
      'pid': 123,
      'executable': r'C:\Program Files\Mozilla Firefox\firefox.exe',
      'protocol': 'tcp',
      'localAddress': '192.0.2.1:12345',
      'remoteAddress': '203.0.113.1:443',
    };
    expect(
      FirefoxProbeResult(
        address: '203.0.113.4',
        browserPid: 122,
        connections: [connection],
      ).toJson(),
      {
        'address': '203.0.113.4',
        'browserPid': 122,
        'connections': [connection],
      },
    );
  });
}
