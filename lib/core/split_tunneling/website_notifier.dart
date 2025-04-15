import 'package:lantern/core/models/website.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/local_storage.dart';
import 'package:lantern/core/services/logger_service.dart';
import 'package:lantern/core/split_tunneling/split_tunnel_filer_type.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'website_notifier.g.dart';

@Riverpod(keepAlive: true)
class SplitTunnelingWebsites extends _$SplitTunnelingWebsites {
  static const String enabledWebsitesKey = "enabled_websites";
  late final LocalStorageService _db;
  late final LanternService _lanternService;

  @override
  Set<Website> build() {
    _db = sl<LocalStorageService>();
    _lanternService = ref.read(lanternServiceProvider);
    return _db.getEnabledWebsites();
  }

  Future<void> addWebsites(List<Website> websites) async {
    final newWebsites = websites.where(
      (w) => !state.any((a) => a.domain == w.domain),
    );

    for (final website in newWebsites) {
      final result = await _lanternService.addSplitTunnelItem(
        SplitTunnelFilterType.domain,
        website.domain,
      );

      result.match(
        (failure) => appLogger.error('Failed to add domain: ${failure.error}'),
        (_) {
          state = {...state, website};
          _db.saveWebsites(state);
        },
      );
    }
  }

  Future<void> removeWebsite(Website website) async {
    if (!state.any((a) => a.domain == website.domain)) return;

    final result = await _lanternService.removeSplitTunnelItem(
      SplitTunnelFilterType.domain,
      website.domain,
    );

    result.match(
      (failure) => appLogger.error('Failed to remove domain: ${failure.error}'),
      (_) {
        state = state.where((a) => a.domain != website.domain).toSet();
        _db.saveWebsites(state);
      },
    );
  }
}
