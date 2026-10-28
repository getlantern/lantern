import 'package:lantern/core/common/app_eum.dart';

enum SplitTunnelPolicy {
  bypass('exclude', 'split_tunnel_bypass'),
  includeOnly('include', 'split_tunnel_include_only');

  const SplitTunnelPolicy(this.wireValue, this.labelKey);

  final String wireValue;
  final String labelKey;
}

class SplitTunnelState {
  const SplitTunnelState({
    required this.enabled,
    required this.policy,
    required this.supported,
    this.filters = const {},
  });

  final bool enabled;
  final SplitTunnelPolicy policy;
  final bool supported;
  final Map<SplitTunnelFilterType, List<String>> filters;

  static const appTypes = [
    SplitTunnelFilterType.processName,
    SplitTunnelFilterType.processPath,
    SplitTunnelFilterType.processPathRegex,
    SplitTunnelFilterType.packageName,
  ];

  factory SplitTunnelState.fromJson(Map<String, dynamic> json) {
    final raw = json['filters'];
    if (json['enabled'] is! bool ||
        !['exclude', 'include'].contains(json['policy']) ||
        raw is! Map) {
      throw const FormatException('Invalid split-tunnel state');
    }
    final filters = <SplitTunnelFilterType, List<String>>{};
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
    final supported = json['supported'] == true;
    return SplitTunnelState(
      enabled: json['enabled'] == true,
      policy: json['policy'] == 'include'
          ? SplitTunnelPolicy.includeOnly
          : SplitTunnelPolicy.bypass,
      supported: supported,
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

  int get websiteCount => SplitTunnelFilterType.values
      .where((type) => !appTypes.contains(type))
      .fold(0, (count, type) => count + selectors(type).length);

  String get statusLabelKey => enabled ? policy.labelKey : 'split_tunnel_off';
}
