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

  Future<void> addWebsite(Website website) async {
    if (state.any((a) => website.domain == a.domain)) return;
    state = {...state, website};
    _db.saveWebsites(state);
  }

  Future<void> removeWebsite(Website website) async {
    if (!state.any((a) => a.domain == website.domain)) return;
    state = state.where((a) => a.domain != website.domain).toSet();
    _db.saveWebsites(state);
  }
}
