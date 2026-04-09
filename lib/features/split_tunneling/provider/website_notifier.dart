import 'dart:async';

import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/models/website.dart';
import 'package:lantern/core/services/logger_service.dart';
import 'package:lantern/core/utils/url_utils.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'website_notifier.g.dart';

@Riverpod(keepAlive: true)
class SplitTunnelingWebsites extends _$SplitTunnelingWebsites {
  late final LanternService _lanternService = ref.read(lanternServiceProvider);
  bool _didLoadInitialState = false;

  @override
  Set<Website> build() {
    if (!_didLoadInitialState) {
      _didLoadInitialState = true;
      unawaited(_reloadFromCore());
    }
    return <Website>{};
  }

  String _normalizeDomain(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return '';
    }
    if (UrlUtils.isValidDomainOrIP(normalized)) {
      return normalized;
    }
    final extracted = UrlUtils.extractDomain(normalized).trim().toLowerCase();
    if (!UrlUtils.isValidDomainOrIP(extracted)) {
      return '';
    }
    return extracted;
  }

  Future<void> _reloadFromCore() async {
    final result = await _lanternService.getSplitTunnelItems(
      SplitTunnelFilterType.domainSuffix,
    );

    result.match(
      (failure) => appLogger.error(
        'Failed to load split-tunnel domains: ${failure.error}',
      ),
      (items) {
        final domains = items
            .map(_normalizeDomain)
            .where((domain) => domain.isNotEmpty)
            .toSet();
        state = domains.map((domain) => Website(domain: domain)).toSet();
      },
    );
  }

  Future<void> addWebsites(List<Website> websites) async {
    final knownDomains = state.map((website) => website.domain).toSet();
    final newDomains = websites
        .map((website) => _normalizeDomain(website.domain))
        .where((domain) => domain.isNotEmpty && !knownDomains.contains(domain))
        .toSet()
        .toList(growable: false);

    if (newDomains.isEmpty) {
      return;
    }

    final result = await _lanternService.addAllItems(
      SplitTunnelFilterType.domainSuffix,
      newDomains,
    );

    result.match(
      (failure) => appLogger.error('Failed to add domain: ${failure.error}'),
      (_) {
        state = {
          ...state,
          ...newDomains.map((domain) => Website(domain: domain)),
        };
      },
    );

    unawaited(_reloadFromCore());
  }

  Future<void> removeWebsite(Website website) async {
    final domain = _normalizeDomain(website.domain);
    if (domain.isEmpty || !state.any((item) => item.domain == domain)) {
      return;
    }

    final result = await _lanternService.removeSplitTunnelItem(
      SplitTunnelFilterType.domainSuffix,
      domain,
    );

    result.match(
      (failure) => appLogger.error('Failed to remove domain: ${failure.error}'),
      (_) {
        state = state.where((item) => item.domain != domain).toSet();
      },
    );

    unawaited(_reloadFromCore());
  }
}
