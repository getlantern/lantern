import 'dart:async';

import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/models/website.dart';
import 'package:lantern/core/services/logger_service.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'website_notifier.g.dart';

@Riverpod(keepAlive: true)
class SplitTunnelingWebsites extends _$SplitTunnelingWebsites {
  late final LanternService _lanternService = ref.read(lanternServiceProvider);

  @override
  FutureOr<Set<Website>> build() async {
    final result = await _lanternService.getSplitTunnelItems(
      SplitTunnelFilterType.domainSuffix,
    );
    return result.match(
      (failure) {
        appLogger.error(
          'Failed to load split-tunnel websites: ${failure.error}',
        );
        return <Website>{};
      },
      (items) => items.map((domain) => Website(domain: domain)).toSet(),
    );
  }

  Set<Website> _current() => state.value ?? <Website>{};

  Future<void> addWebsites(List<Website> websites) async {
    final current = _current();
    final newWebsites = websites.where(
      (w) => !current.any((a) => a.domain == w.domain),
    );

    for (final website in newWebsites) {
      final result = await _lanternService.addSplitTunnelItem(
        SplitTunnelFilterType.domainSuffix,
        website.domain,
      );

      result.match(
        (failure) => appLogger.error('Failed to add domain: ${failure.error}'),
        (_) {
          state = AsyncData({...state.value ?? <Website>{}, website});
        },
      );
    }
  }

  Future<void> removeWebsite(Website website) async {
    final current = _current();
    if (!current.any((a) => a.domain == website.domain)) return;

    final result = await _lanternService.removeSplitTunnelItem(
      SplitTunnelFilterType.domainSuffix,
      website.domain,
    );

    result.match(
      (failure) => appLogger.error('Failed to remove domain: ${failure.error}'),
      (_) {
        state = AsyncData(
          (state.value ?? <Website>{})
              .where((a) => a.domain != website.domain)
              .toSet(),
        );
      },
    );
  }
}
