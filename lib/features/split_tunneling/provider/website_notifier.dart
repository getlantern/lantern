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
  Set<Website> build() {
    return <Website>{};
  }

  Future<void> addWebsites(List<Website> websites) async {
    final newWebsites = websites.where(
      (w) => !state.any((a) => a.domain == w.domain),
    );

    for (final website in newWebsites) {
      final result = await _lanternService.addSplitTunnelItem(
        SplitTunnelFilterType.domainSuffix,
        website.domain,
      );

      result.match(
        (failure) => appLogger.error('Failed to add domain: ${failure.error}'),
        (_) {
          state = {...state, website};
        },
      );
    }
  }

  Future<void> removeWebsite(Website website) async {
    if (!state.any((a) => a.domain == website.domain)) return;

    final result = await _lanternService.removeSplitTunnelItem(
      SplitTunnelFilterType.domainSuffix,
      website.domain,
    );

    result.match(
      (failure) => appLogger.error('Failed to remove domain: ${failure.error}'),
      (_) {
        state = state.where((a) => a.domain != website.domain).toSet();
      },
    );
  }
}
