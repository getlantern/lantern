import 'dart:async';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/core/services/injection_container.dart' show sl;
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/core/utils/helper_tags.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'server_location_notifier.g.dart';

@Riverpod(keepAlive: true)
class ServerLocationNotifier extends _$ServerLocationNotifier {
  LocalStorageService get _storage => sl<LocalStorageService>();

  // Bumped by every selection change, so a radiance fetch that started
  // before one does not overwrite it.
  int _selection = 0;

  @override
  ServerLocation build() {
    // Every change to the selected/resolved location is mirrored into the
    // native widget so it can show where the tunnel exits.
    listenSelf((_, next) => _publishToWidget(next));
    ref.listen(vpnProvider, (_, next) => _settlePendingSelection(next));
    // radiance drops the personal proxies group with the last pairing and
    // connects through auto, but sends no server-location event for it.
    // fireImmediately covers a view that loaded empty before this notifier
    // was built; the check is deferred because state is unset during build.
    // An empty local view is not proof: after a keystore reset unlock
    // returns no pairings until a refresh recovers the remote ones, so the
    // switch waits for radiance to confirm the group is gone. The config
    // that drops it can land after the view, so the server list calls
    // [reconcilePersonalProxy] again when it changes.
    ref.listen(helpersProvider, (_, next) {
      if (!_helpersGone(next)) return;
      unawaited(Future.microtask(reconcilePersonalProxy));
    }, fireImmediately: true);
    final cached = _storage.getServerLocation();
    final initial = cached ?? _defaultLocation();
    appLogger.debug(
      'ServerLocationNotifier.build() cached=${cached != null} '
      'type=${initial.serverType} city=${initial.city}',
    );
    // Use cached value for instant display, then refresh from radiance.
    fetchServerLocation();
    return initial;
  }

  static bool _trusted(HelpersState s) =>
      s.viewLoaded && !s.keystoreReset && s.error == null;

  static bool _helpersGone(HelpersState s) =>
      _trusted(s) && s.view.helpers.isEmpty;

  bool get _personalProxySelected =>
      state.serverType.toServerLocationType == ServerLocationType.personalProxy;

  /// Switches a personal proxy selection to auto once the helpers view is
  /// loaded empty and radiance no longer has the personal proxies group.
  /// [fromConfig] is a config refresh: a friend may have ended the pairing
  /// remotely, so a non-empty view is refreshed once before giving up.
  Future<void> reconcilePersonalProxy({bool fromConfig = false}) async {
    if (!ref.mounted || !_personalProxySelected) return;
    final before = ref.read(helpersProvider);
    final stale =
        fromConfig && _trusted(before) && before.view.helpers.isNotEmpty;
    if (!stale && !_helpersGone(before)) return;
    final bool available;
    try {
      available = await ref
          .read(lanternServiceProvider)
          .isTagAvailable(personalProxiesTag);
    } catch (e) {
      appLogger.debug('personal proxies: tag check failed: $e');
      return;
    }
    if (!ref.mounted || available || !_personalProxySelected) return;
    if (stale) {
      await ref.read(helpersProvider.notifier).refreshIfUsed();
      if (!ref.mounted || !_personalProxySelected) return;
    }
    if (!_helpersGone(ref.read(helpersProvider))) return;
    await switchToAuto();
    await refreshAutoLocationIfNeeded();
  }

  // Numbers each read of radiance's selection: only the newest started read
  // is applied.
  int _reads = 0;

  /// Mirrors the selection radiance has persisted, the one source of truth.
  /// Called when a connect returns, on a personal proxy fallback and on a
  /// server-location event. Each call starts a fresh read and only the newest
  /// started read is applied, so the last one always reflects radiance's
  /// latest state. A failed read changes nothing.
  Future<void> syncSelection() async {
    final read = ++_reads;
    Object? tag;
    try {
      final res = await ref
          .read(lanternServiceProvider)
          .helperCall('selected_server', const {});
      final r = res.fold(
        (_) => HelperResult.failure('unavailable'),
        HelperResult.parse,
      );
      if (r.ok) tag = r.data['tag'];
    } catch (_) {
      return;
    }
    if (!ref.mounted || read != _reads || tag is! String || tag.isEmpty) {
      return;
    }
    if (tag == 'auto') {
      if (state.serverType == ServerLocationType.auto.name) return;
      await switchToAuto();
      await refreshAutoLocationIfNeeded();
      return;
    }
    final friend = personalProxyFriend(tag);
    if (tag == personalProxiesTag || friend != null) {
      if (state.serverName == tag) return;
      updateServerLocation(ServerLocation.personalProxy(friendTag: friend));
      return;
    }
    // A Lantern or private server: already shown with its details, or
    // fetched from radiance.
    if (state.serverName == tag &&
        state.serverType != ServerLocationType.auto.name) {
      return;
    }
    final result = await ref
        .read(lanternServiceProvider)
        .getSelectedServerLocation();
    if (!ref.mounted || read != _reads) return;
    result.fold((_) {}, updateServerLocation);
  }

  /// Fetches the current server location from radiance.
  /// If the VPN isn't connected, uses the cached value.
  /// If auto-selected, fetches the auto location; otherwise fetches the
  /// explicitly selected server.
  Future<void> fetchServerLocation() async {
    final status = ref.read(vpnProvider);
    if (status != VPNStatus.connected) {
      appLogger.debug(
        'fetchServerLocation: VPN not connected ($status), using cached value',
      );
      return;
    }

    final cached = _storage.getServerLocation();
    final isAuto =
        cached == null ||
        cached.serverType.toServerLocationType == ServerLocationType.auto;

    appLogger.debug('fetchServerLocation: VPN connected, isAuto=$isAuto');

    if (isAuto) {
      await _fetchAutoLocation();
    } else {
      await _fetchSelectedLocation();
    }
  }

  Future<void> _fetchAutoLocation() async {
    appLogger.debug('Fetching auto server location from radiance...');
    final selection = _selection;
    final result = await ref
        .read(lanternServiceProvider)
        .getAutoServerLocation();
    if (!ref.mounted || selection != _selection) return;
    result.fold(
      (error) {
        // Expected when VPN isn't connected yet — auto location is only
        // available after the tunnel starts. The cached value (from the
        // last session) is used until the server-location event arrives.
        appLogger.debug('Auto server location not available yet: $error');
      },
      (autoServer) {
        final location = ServerLocation.autoSelected(autoServer);
        appLogger.debug(
          'Fetched auto server location: ${location.toLogJson()}',
        );
        state = location;
        _storage.saveServerLocation(location);
      },
    );
  }

  Future<void> _fetchSelectedLocation() async {
    appLogger.debug('Fetching selected server location from radiance...');
    final selection = _selection;
    final result = await ref
        .read(lanternServiceProvider)
        .getSelectedServerLocation();
    if (!ref.mounted || selection != _selection) return;
    result.fold(
      (error) {
        appLogger.error(
          'Failed to fetch selected server from radiance: $error',
          error,
        );
      },
      (location) {
        appLogger.debug(
          'Fetched selected server location: ${location.toLogJson()}',
        );
        state = location;
        _storage.saveServerLocation(location);
      },
    );
  }

  void updateServerLocation(ServerLocation entity) {
    final current = state;
    final ServerLocation updated;
    if (entity.serverType != ServerLocationType.auto.name) {
      //Preserve auto location metadata when switching to a non-auto server,
      // so we can show user smart location
      updated = entity.copyWith(autoLocation: current.autoLocation);
    } else {
      updated = entity;
    }
    appLogger.debug(
      'updateServerLocation: type=${updated.serverType} '
      'name=${updated.serverName} city=${updated.city}',
    );
    _selection++;
    state = updated;
    _storage.saveServerLocation(updated);
  }

  Future<void> refreshAutoLocationIfNeeded() async {
    final status = ref.read(vpnProvider);
    final current = state;
    final isAuto =
        current.serverType.toServerLocationType == ServerLocationType.auto;

    appLogger.debug('refreshAutoLocationIfNeeded: vpn=$status isAuto=$isAuto');

    if (status == VPNStatus.connected && isAuto) {
      await _fetchAutoLocation();
    }
  }

  /// Flips the active selection to auto and clears any stale custom-server
  /// identity fields so downstream UI does not keep highlighting a previous
  /// manual selection. The existing [autoLocation] metadata is preserved so
  /// the Smart Location label remains available until the next push event.
  Future<void> switchToAuto() async {
    if (state.serverType == ServerLocationType.auto.name) return;
    final updated = state.copyWith(serverType: ServerLocationType.auto.name);
    _selection++;
    state = updated;
    await _storage.saveServerLocation(updated);
  }

  _PendingSelection? _pending;

  /// Runs [save] once the VPN reports connected, so the stored selection never
  /// gets ahead of the status the home screen shows. Owned here rather than by
  /// the selection screen so leaving that screen doesn't drop the save. A newer
  /// request, disconnect, or VPN error retires a pending one. Resolves true once
  /// the VPN connected and [save] ran, false if the request was retired.
  Future<bool> saveOnceConnected(FutureOr<void> Function() save) {
    _retirePendingSelection();
    if (ref.read(vpnProvider) == VPNStatus.connected) {
      return _runSave(save).then((_) => true);
    }
    final pending = _PendingSelection(save);
    _pending = pending;
    return pending.completer.future;
  }

  void _settlePendingSelection(VPNStatus status) {
    final pending = _pending;
    if (pending == null) return;
    if (status == VPNStatus.connected) {
      _pending = null;
      unawaited(
        _runSave(pending.save).then((_) => pending.completer.complete(true)),
      );
    } else if (status == VPNStatus.disconnected || status == VPNStatus.error) {
      _retirePendingSelection();
    }
  }

  void _retirePendingSelection() {
    _pending?.completer.complete(false);
    _pending = null;
  }

  // A failed save must not strand the user on the selection screen.
  Future<void> _runSave(FutureOr<void> Function() save) async {
    try {
      await save();
    } catch (e, stack) {
      appLogger.error('Failed to save server selection: $e', e, stack);
    }
  }

  void _publishToWidget(ServerLocation location) {
    final isAuto =
        location.serverType.toServerLocationType == ServerLocationType.auto;
    final auto = location.autoLocation;
    unawaited(
      ref
          .read(lanternServiceProvider)
          .updateWidgetLocation(
            city: location.city,
            country: isAuto ? (auto?.country ?? '') : location.country,
            countryCode: isAuto
                ? (auto?.countryCode ?? '')
                : location.countryCode,
            displayName: isAuto
                ? (auto?.displayName ?? '')
                : location.displayName,
            // A widget connect dials what the app has selected now, so the
            // last publish wins over any native write made mid-switch.
            serverName: isAuto ? '' : location.serverName,
          ),
    );
  }

  static ServerLocation _defaultLocation() => ServerLocation(
    serverType: ServerLocationType.auto.name,
    serverName: '',
    displayName: '',
    protocol: '',
    city: '',
  );
}

class _PendingSelection {
  final FutureOr<void> Function() save;
  final completer = Completer<bool>();

  _PendingSelection(this.save);
}
