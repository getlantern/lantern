import 'dart:async';

import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/models/website.dart';
import 'package:lantern/core/services/logger_service.dart';
import 'package:lantern/core/utils/failure.dart';
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
      (items) => items
          .map((item) => item.trim().toLowerCase())
          .where((domain) => domain.isNotEmpty)
          .map((domain) => Website(domain: domain))
          .toSet(),
    );
  }

  Set<Website> _current() => state.value ?? <Website>{};

  Future<void> refreshFromCore() => _reloadFromCore();

  Future<void> _reloadFromCore() async {
    final result = await _lanternService.getSplitTunnelItems(
      SplitTunnelFilterType.domainSuffix,
    );

    result.match(
      (failure) => appLogger.error(
        'Failed to load split-tunnel websites: ${failure.error}',
      ),
      (items) {
        state = AsyncData(
          items
              .map((item) => item.trim().toLowerCase())
              .where((domain) => domain.isNotEmpty)
              .map((domain) => Website(domain: domain))
              .toSet(),
        );
      },
    );
  }

  Future<List<Failure>> addWebsites(List<Website> websites) async {
    final failures = <Failure>[];
    final current = _current();
    final newWebsites = websites.where(
      (website) =>
          !current.any(
            (saved) =>
                saved.domain.toLowerCase() == website.domain.toLowerCase(),
          ) &&
          website.domain.trim().isNotEmpty,
    );

    var reloaded = false;
    for (final website in newWebsites) {
      final normalizedDomain = website.domain.trim().toLowerCase();
      final result = await _lanternService.addSplitTunnelItem(
        SplitTunnelFilterType.domainSuffix,
        normalizedDomain,
      );

      result.match(
        (failure) {
          appLogger.error(
            'Failed to add split-tunnel website "$normalizedDomain": ${failure.error}',
          );
          failures.add(failure);
        },
        (_) {
          reloaded = true;
        },
      );
    }

    if (reloaded) {
      await _reloadFromCore();
    }

    return failures;
  }

  Future<Failure?> removeWebsite(Website website) async {
    final normalizedDomain = website.domain.trim().toLowerCase();
    if (normalizedDomain.isEmpty) {
      return null;
    }

    final current = _current();
    if (!current.any((saved) => saved.domain.toLowerCase() == normalizedDomain)) {
      return null;
    }

    final result = await _lanternService.removeSplitTunnelItem(
      SplitTunnelFilterType.domainSuffix,
      normalizedDomain,
    );

    final failure = result.match((failure) {
      appLogger.error(
        'Failed to remove split-tunnel website "$normalizedDomain": ${failure.error}',
      );
      return failure;
    }, (_) => null);

    if (failure != null) {
      return failure;
    }

    await _reloadFromCore();
    return null;
  }
}
