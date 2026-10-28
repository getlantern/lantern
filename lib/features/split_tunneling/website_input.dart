import 'dart:io';

String parseSplitTunnelWebsite(String input) {
  var value = input.trim().replaceAll(RegExp('[\u3002\uff0e\uff61]'), '.');
  final wildcard = value.startsWith('*.');
  if (wildcard) value = value.substring(2);
  if (value.isEmpty ||
      value.contains('*') ||
      value.startsWith('.') ||
      value.contains(RegExp(r'\s'))) {
    throw const FormatException('Invalid website wildcard');
  }
  if (value.contains('://')) {
    final uri = Uri.tryParse(value);
    if (wildcard ||
        uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.userInfo.isNotEmpty ||
        uri.host.isEmpty ||
        (uri.hasPort && (uri.port < 1 || uri.port > 65535))) {
      throw const FormatException('Invalid website URL');
    }
    value = uri.host;
  } else if (value.contains(RegExp(r'[/\\:@?#%]'))) {
    throw const FormatException('Expected a website host');
  }
  value = value.toLowerCase();
  if (value.endsWith('.')) value = value.substring(0, value.length - 1);
  _validateHost(value, asciiOnly: false, wildcard: wildcard);
  return wildcard ? '.$value' : value;
}

String validateCanonicalSplitTunnelWebsite(String value) {
  final wildcard = value.startsWith('.');
  final host = wildcard ? value.substring(1) : value;
  _validateHost(host, asciiOnly: true, wildcard: wildcard);
  if (host != host.toLowerCase()) {
    throw const FormatException('Noncanonical website host');
  }
  return value;
}

void _validateHost(
  String host, {
  required bool asciiOnly,
  required bool wildcard,
}) {
  final labels = host.split('.');
  if (host.isEmpty ||
      host.length > 253 ||
      InternetAddress.tryParse(host) != null ||
      RegExp(r'^[0-9.]+$').hasMatch(host) ||
      (!wildcard && labels.length < 2)) {
    throw const FormatException('Expected a domain, not an IP address');
  }
  final labelPattern = asciiOnly
      ? RegExp(r'^[a-z0-9-]+$')
      : RegExp(r'^[\p{L}\p{M}\p{N}-]+$', unicode: true);
  for (final label in labels) {
    if (label.isEmpty ||
        label.length > 63 ||
        label.startsWith('-') ||
        label.endsWith('-') ||
        !labelPattern.hasMatch(label)) {
      throw const FormatException('Invalid website label');
    }
  }
}
