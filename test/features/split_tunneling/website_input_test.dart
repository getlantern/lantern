import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/models/website.dart';
import 'package:lantern/features/split_tunneling/website_input.dart';

void main() {
  test('preserves complete hosts, long TLDs and URL hosts', () {
    for (final entry in {
      ' WWW.Example.CO.UK. ': 'www.example.co.uk',
      'https://News.Example.technology:8443/path?q=x#fragment':
          'news.example.technology',
      '*.Example.COM.': '.example.com',
      '*.ir': '.ir',
      'BÜCHER。Example': 'bücher.example',
    }.entries) {
      expect(parseSplitTunnelWebsite(entry.key), entry.value);
    }
  });

  test(
    'rejects ambiguous wildcards, malformed labels, IPs and non-web URLs',
    () {
      for (final value in [
        '',
        '*',
        '*ir',
        'ex*ample.com',
        'foo.*.com',
        '**.example.com',
        '.example.com',
        'localhost',
        'example..com',
        '-example.com',
        'example-.com',
        'foo_bar.com',
        'example.com..',
        '127.0.0.1',
        '127.000.0.1',
        '*.127.0.0.1',
        '[::1]',
        'https://[::1]/',
        'ftp://example.com',
        'https://user@example.com',
        'example.com/path',
        'https://example.com:99999',
        'https://example.com:0',
        'https://example.com/a b',
        '${'a' * 64}.com',
      ]) {
        expect(
          () => parseSplitTunnelWebsite(value),
          throwsFormatException,
          reason: value,
        );
      }
    },
  );

  test('canonical forms keep subdomain-only marker and display wildcard', () {
    expect(
      validateCanonicalSplitTunnelWebsite('.xn--bcher-kva.example'),
      '.xn--bcher-kva.example',
    );
    expect(Website(domain: '.example.com').displayDomain, '*.example.com');
    expect(
      Website(domain: 'news.example.com').displayDomain,
      'news.example.com',
    );
    for (final value in [
      '*.example.com',
      'EXAMPLE.com',
      '.example..com',
      'bücher.example',
      '127.0.0.1',
    ]) {
      expect(
        () => validateCanonicalSplitTunnelWebsite(value),
        throwsFormatException,
      );
    }
  });
}
