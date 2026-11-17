import 'package:lantern/core/common/app_eum.dart';

enum SplitTunnelPolicy {
  bypass('exclude', 'split_tunnel_bypass', 'split_tunnel_bypass_description'),
  includeOnly(
    'include',
    'split_tunnel_include_only',
    'split_tunnel_include_description',
  );

  const SplitTunnelPolicy(this.wireValue, this.labelKey, this.descriptionKey);

  final String wireValue;
  final String labelKey;
  final String descriptionKey;
}

class SplitTunnelState {
  const SplitTunnelState({
    required this.enabled,
    required this.policy,
    this.filters = const {},
  });

  final bool enabled;
  final SplitTunnelPolicy policy;
  final Map<SplitTunnelFilterType, List<String>> filters;

  static const appTypes = [
    SplitTunnelFilterType.processName,
    SplitTunnelFilterType.processPath,
    SplitTunnelFilterType.processPathRegex,
    SplitTunnelFilterType.packageName,
  ];

  factory SplitTunnelState.fromJson(Map<String, dynamic> json) {
    final raw = json['filters'];
    final filters = <SplitTunnelFilterType, List<String>>{};
    if (raw is Map) {
      for (final type in SplitTunnelFilterType.values) {
        final name = type.value;
        final entries =
            raw[name] ?? raw['${name[0].toUpperCase()}${name.substring(1)}'];
        if (entries is List) {
          filters[type] = List.unmodifiable(
            entries.whereType<String>().where((s) => s.isNotEmpty).toSet(),
          );
        }
      }
    }
    return SplitTunnelState(
      enabled: json['enabled'] == true,
      policy: json['policy'] == 'include'
          ? SplitTunnelPolicy.includeOnly
          : SplitTunnelPolicy.bypass,
      filters: Map.unmodifiable(filters),
    );
  }

  List<String> selectors(SplitTunnelFilterType type) =>
      filters[type] ?? const [];

  Iterable<String> appSelectors(SplitTunnelFilterType type) =>
      selectors(type).where(
        (selector) =>
            type != SplitTunnelFilterType.processPathRegex ||
            !_hasManagedPath(selector),
      );

  // Hides the regex aliases Go adds for a selected Windows path (see
  // aliasPatternPrefix in processpath), since the path row already shows it.
  bool _hasManagedPath(String selector) {
    const prefix = '(?i)^(?P<lantern_windows_executable>)';
    if (!selector.startsWith(prefix)) return false;
    try {
      final pattern = RegExp(
        '^${selector.substring(prefix.length)}',
        caseSensitive: false,
      );
      return selectors(
        SplitTunnelFilterType.processPath,
      ).any((path) => pattern.hasMatch(path.replaceAll('/', r'\')));
    } on FormatException {
      return false;
    }
  }

  int get appCount =>
      appTypes.fold(0, (count, type) => count + appSelectors(type).length);

  int get websiteCount => selectors(SplitTunnelFilterType.domainSuffix).length;

  String get statusLabelKey => enabled ? policy.labelKey : 'split_tunnel_off';
}
