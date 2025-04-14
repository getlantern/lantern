import 'package:lantern/core/models/website.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/local_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'website_notifier.g.dart';

@Riverpod(keepAlive: true)
class SplitTunnelingWebsites extends _$SplitTunnelingWebsites {
  static const String enabledWebsitesKey = "enabled_websites";
  late final LocalStorageService _db;

  @override
  Set<Website> build() {
    _db = sl<LocalStorageService>();
    return _db.getEnabledWebsites();
  }

  Future<void> addWebsites(List<Website> websites) async {
    final newWebsites = websites.where(
      (w) => !state.any((a) => a.domain == w.domain),
    );
    state = {...state, ...newWebsites};
    _db.saveWebsites(state);
  }

  Future<void> removeWebsite(Website website) async {
    if (!state.any((a) => a.domain == website.domain)) return;
    state = state.where((a) => a.domain != website.domain).toSet();
    _db.saveWebsites(state);
  }
}
