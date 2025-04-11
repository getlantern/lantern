import 'package:lantern/core/models/website_data.dart';
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

  // Toggle app selection for split tunneling
  Future<void> toggleWebsite(Website website) async {
    final isCurrentlyEnabled = state.any((a) => website.domain == a.domain);

    if (isCurrentlyEnabled) {
      state = state.where((a) => a.domain != website.domain).toSet();
    } else {
      state = {...state, website.copyWith(isEnabled: true)};
    }

    _db.saveWebsites(state);
  }
}
