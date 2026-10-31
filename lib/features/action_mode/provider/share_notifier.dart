import 'dart:async';
import 'dart:convert';
import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/action_mode_connection_event.dart';
import 'package:lantern/core/models/app_event.dart';
import 'package:lantern/core/models/relay_stats.dart';
import 'package:lantern/core/models/share_state.dart';
import 'package:lantern/core/services/geo_lookup_service.dart';
import 'package:lantern/core/services/injection_container.dart' show sl;
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/core/utils/country_code.dart';
import 'package:lantern/features/action_mode/share_consent_dialog.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/home/provider/radiance_settings_providers.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'share_notifier.g.dart';

/// Drives connection sharing in both modes: Unbounded (broflake/WebRTC) and
/// the samizdat-over-UPnP "Share My Connection" (SmC) mode.
///
/// Turning sharing on collects consent, then picks the mode from the network:
/// a manual port or a working UPnP gateway means SmC, anything else means
/// Unbounded. SmC start failures fall back to Unbounded transparently.
@Riverpod(keepAlive: true)
class ShareNotifier extends _$ShareNotifier {
  // ─── Consent ───────────────────────────────────────────────────────────────

  static const _consentAckKey = 'share_consent_acked';
  // The old SmC-only disclosure covered the stronger (exit-node) case, so that
  // ack carries forward.
  static const _legacySmcAckKey = 'smc_disclosure_acked';

  Future<bool>? _consentInFlight;

  LocalStorageService get _storage => sl<LocalStorageService>();

  bool get _consentAcked =>
      _storage.containsKey(_consentAckKey) ||
      _storage.containsKey(_legacySmcAckKey);

  // ─── Sharing session ───────────────────────────────────────────────────────

  StreamSubscription? _appEventSub;
  StreamSubscription? _snapshotSub;
  // Number of start/stop transitions in flight; snapshots and toggles are
  // ignored while non-zero.
  int _changes = 0;
  bool get _changing => _changes > 0;

  // ─── Peer tracking ─────────────────────────────────────────────────────────

  String? _snapshotEpoch;
  int _lastArrivals = 0;
  bool _hasUnboundedSnapshot = false;
  int _workerSeq = 0;
  // Keyed by peer IP. samizdat multiplexes many streams over one connection,
  // so each arc is ref-counted and stays until the peer's last stream closes.
  final Map<String, _PeerArc> _peerArcs = {};

  // ─── Relay stats ───────────────────────────────────────────────────────────

  @visibleForTesting
  Duration relayPersistInterval = const Duration(seconds: 30);
  // Weight of the newest sample in the smoothed speed.
  static const _speedSmoothing = 0.5;

  // Unbounded and SmC report counters in separate snapshots with their own
  // epochs, so each needs its own tracker, sample clock and persisted
  // watermark.
  final _unboundedFeed = _RelayFeed();
  final _peerFeed = _RelayFeed();
  DateTime? _lastRelayPersistAt;
  Timer? _relayPersistTimer;
  bool _relayDirty = false;

  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  final _eventController =
      StreamController<ActionModeConnectionEvent>.broadcast();

  /// Geo-resolved connection changes for the globe and the arrival toast.
  Stream<ActionModeConnectionEvent> get connectionEvents =>
      _eventController.stream;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  ShareState build() {
    _snapshotSub = ref
        .read(lanternServiceProvider)
        .watchAppEvents()
        .listen(_handleUnboundedEvent);
    ref.onDispose(() {
      _snapshotSub?.cancel();
      _stopEventSubscription();
      _eventController.close();
      _relayPersistTimer?.cancel();
    });
    // A held-back helper start is for the people this device helps: once it
    // helps nobody, there is nothing left to start for.
    ref.listen<bool>(helpersProvider.select((s) => s.view.helping.isEmpty), (
      _,
      helpsNobody,
    ) {
      if (helpsNobody) _helperStartPending = false;
    });

    final settings = ref.read(appSettingProvider);
    // Earlier builds enabled auto-start without a disclosure. autoStart refuses
    // to run without an ack, so clear the preference rather than grandfather it.
    // Deferred because build() must not mutate another provider.
    if (!_consentAcked && settings.unboundedAutoEnable) {
      Future.microtask(
        () =>
            ref.read(appSettingProvider.notifier).setUnboundedAutoEnable(false),
      );
    }
    _unboundedFeed.counters.restore(
      epoch: settings.unboundedRelayEpoch,
      down: settings.unboundedRelayMarkDown,
      up: settings.unboundedRelayMarkUp,
    );
    _peerFeed.counters.restore(
      epoch: settings.peerRelayEpoch,
      down: settings.peerRelayMarkDown,
      up: settings.peerRelayMarkUp,
    );
    return ShareState(
      totalCount: settings.unboundedTotalHelped,
      relay: RelayStats(
        lifetimeDown: settings.unboundedBytesDown,
        lifetimeUp: settings.unboundedBytesUp,
        countries: settings.unboundedCountryStats,
      ),
    );
  }

  /// Toggles sharing. Shows the consent dialog inline when needed, then
  /// picks the mode from the network.
  Future<void> toggle(BuildContext context, WidgetRef widgetRef) async {
    if (_changing) return;
    // The user has chosen, on or off: a held-back helper start must not
    // override that later.
    _helperStartPending = false;
    _changes++;
    try {
      await _toggle(context, widgetRef);
    } finally {
      _changes--;
    }
  }

  /// Starts Unbounded without UI. Used by the VPN-connected auto-enable hook.
  /// Always Unbounded, never SmC: this path cannot disclose that the device
  /// would become a residential exit. No-ops without a prior consent ack.
  Future<void> autoStart(WidgetRef widgetRef) =>
      _autoStartWith(() => _start(widgetRef, ShareMode.unbounded));

  /// Adopts an SmC session that radiance resumed from persisted settings
  /// before this notifier existed. The peer-status stream is edge-triggered,
  /// so without this the UI opens at off while SmC is already serving.
  Future<void> syncFromBackend(WidgetRef widgetRef) async {
    if (state.active || state.probing) return;
    final res = await widgetRef
        .read(lanternServiceProvider)
        .getPeerStatusJSON();
    if (!ref.mounted) return;
    if (state.active || state.probing) return;
    final phase = adoptablePhase(res.fold((_) => '', (v) => v));
    if (phase == null) return;
    state = state.copyWith(active: true, mode: ShareMode.smc, phase: phase);
    _startEventSubscription(widgetRef);
  }

  /// The phase to adopt from a raw peer-status payload, or null to leave
  /// state untouched. Only phases that mean sharing is genuinely up qualify:
  /// idle means the backend agrees we are off, error is owned by the toggle
  /// path's Unbounded fallback, and a missing phase means the read failed.
  @visibleForTesting
  SharePhase? adoptablePhase(String raw) {
    if (raw.isEmpty) return null;
    final SharePhase phase;
    try {
      final payload = jsonDecode(raw) as Map<String, dynamic>;
      if (payload['phase'] == null) return null;
      phase = SharePhase.fromWire(payload['phase'] as String?);
    } catch (e) {
      debugPrint('share-my-connection: bad peer status: $e');
      return null;
    }
    return switch (phase) {
      SharePhase.idle || SharePhase.error || SharePhase.stopping => null,
      SharePhase.mappingPort ||
      SharePhase.detectingIp ||
      SharePhase.registering ||
      SharePhase.startingProxy ||
      SharePhase.verifying ||
      SharePhase.serving => phase,
    };
  }

  /// Prompts for consent if not yet given and reports whether sharing may
  /// proceed. Concurrent callers share one dialog.
  Future<bool> ensureConsent(BuildContext context) {
    if (_consentAcked) return Future.value(true);
    return _consentInFlight ??= _showConsentDialog(
      context,
    ).whenComplete(() => _consentInFlight = null);
  }

  /// Persists the auto-start preference, collecting consent first when
  /// enabling. autoStart refuses to run without an ack, so a preference
  /// written without one would read as enabled and never start.
  Future<void> setAutoEnable(BuildContext context, bool enabled) async {
    final settings = ref.read(appSettingProvider.notifier);
    if (!enabled) {
      settings.setUnboundedAutoEnable(false);
      return;
    }
    if (!await ensureConsent(context)) return;
    if (!ref.mounted) return;
    settings.setUnboundedAutoEnable(true);
  }

  /// Re-emits a +1 for every geo-resolved active peer so a globe that mounts
  /// mid-session starts from the current world state.
  void replayCurrentPeers() {
    for (final arc in _peerArcs.values) {
      final geo = arc.geo;
      if (geo == null) continue;
      _emitConnected(arc, geo, isReplay: true);
    }
  }

  Future<void> _toggle(BuildContext context, WidgetRef widgetRef) async {
    if (state.active || state.probing) {
      await _stop(widgetRef);
      return;
    }
    if (!await ensureConsent(context)) return;
    if (!ref.mounted) return;
    // Another surface may have started sharing while the dialog was up.
    if (state.active || state.probing) return;

    state = state.copyWith(probing: true);

    await _startAuto(widgetRef);
  }

  /// Picks the sharing mode from the network and starts it: direct (SmC)
  /// where a manual port or UPnP gateway allows, Unbounded otherwise. The
  /// spec's "Mode": direct whenever it works, with no picker.
  ///
  /// [mayStart], when given, is asked again right before the backend is
  /// enabled, after the port and UPnP checks; false abandons the start.
  Future<void> _startAuto(
    WidgetRef widgetRef, {
    bool Function()? mayStart,
  }) async {
    Future<void> start(ShareMode mode) async {
      if (mayStart != null && !mayStart()) {
        state = state.copyWith(probing: false);
        return;
      }
      _startGuard = mayStart;
      await _start(widgetRef, mode);
    }

    // The iOS network extension cannot carry the peer proxy's second sing-box
    // instance, so the backend refuses SmC there.
    if (PlatformUtils.isIOS) {
      await start(ShareMode.unbounded);
      return;
    }

    // A manually forwarded port is an explicit request for SmC.
    final manualPortRes = await widgetRef
        .read(lanternServiceProvider)
        .getPeerManualPort();
    if (!ref.mounted) return;
    if (manualPortRes.fold((_) => 0, (p) => p) > 0) {
      await start(ShareMode.smc);
      return;
    }

    // Blocks up to ~6s on IGD discovery; any failure counts as unavailable.
    final probeRes = await widgetRef.read(lanternServiceProvider).probeUPnP();
    if (!ref.mounted) return;
    final upnpAvailable = probeRes.fold((_) => false, (v) => v);
    await start(upnpAvailable ? ShareMode.smc : ShareMode.unbounded);
  }

  /// The [_startAuto] guard of the running session, asked again before an
  /// SmC failure falls back to Unbounded. Null for a start the user made.
  bool Function()? _startGuard;

  /// A helper approval whose start was held back because this device's
  /// country was unknown or censored. Memory only.
  bool _helperStartPending = false;

  /// Starts sharing for a newly approved helper pairing, as the toggle would.
  /// The consent was collected when the user accepted the invite; without it
  /// this does nothing. A user who later turns sharing off stays off.
  ///
  /// Never starts while this device's own country is unknown or censored:
  /// lantern-cloud's guard relies on IP geolocation and can fail open. The
  /// approval is then kept, and [retryPendingHelperStart] starts it once the
  /// country is known and allowed. The user can still turn sharing on.
  Future<void> startForHelper(WidgetRef widgetRef) async {
    if (!_helperStartAllowed()) return;
    // Held until a start actually proceeds: one skipped because another
    // change is in flight or sharing is already up is retried later.
    _helperStartPending = true;
    await _autoStartWith(() {
      _helperStartPending = false;
      return _startAuto(widgetRef, mayStart: _helperStartAllowed);
    });
  }

  /// Whether a helper start may run now. Asked again after the port and UPnP
  /// checks, since the country or the pairing can change while they run.
  bool _helperStartAllowed() {
    // An approval can be counted from a view older than the one applied,
    // after the pairing already ended: start only for someone still helped.
    if (ref.read(helpersProvider).view.helping.isEmpty) {
      _helperStartPending = false;
      return false;
    }
    if (!helperAutoStartAllowed(CountryCode.current)) {
      _helperStartPending = true;
      return false;
    }
    return true;
  }

  /// Retries a helper start held back by [startForHelper]. Called when the
  /// country changes. Dropped if this device no longer helps anyone.
  Future<void> retryPendingHelperStart(WidgetRef widgetRef) async {
    if (_helperStartPending) await startForHelper(widgetRef);
  }

  /// The no-UI start shared by autoStart and startForHelper: skip while a
  /// change is in flight or sharing is already up, and never start without
  /// the consent ack.
  Future<void> _autoStartWith(Future<void> Function() start) async {
    if (_changing || state.active || state.probing) return;
    if (!_consentAcked) return;
    _changes++;
    try {
      state = state.copyWith(probing: true);
      await start();
    } finally {
      _changes--;
    }
  }

  Future<void> _start(WidgetRef widgetRef, ShareMode mode) async {
    state = ShareState(
      active: true,
      mode: mode,
      totalCount: state.totalCount,
      relay: state.relay.newSession(),
    );
    _startEventSubscription(widgetRef);
    switch (mode) {
      case ShareMode.smc:
        // A failed Start reports itself twice: as the error returned here and
        // as a phase=error event. Both fall back; the second is ignored.
        final res = await widgetRef
            .read(radianceSettingsProvider.notifier)
            .setPeerProxy(true);
        if (!ref.mounted) return;
        res.fold((err) {
          appLogger.error(
            'SmC setPeerProxy failed, falling back to Unbounded: ${err.error}',
          );
          unawaited(_fallbackToUnbounded(widgetRef, err.error));
        }, (_) => _recordSessionStart());
      case ShareMode.unbounded:
        final res = await widgetRef
            .read(lanternServiceProvider)
            .setUnboundedEnabled(true);
        if (!ref.mounted) return;
        res.fold((err) {
          appLogger.error('setUnboundedEnabled failed: ${err.error}');
          _failOff(err.error);
        }, (_) => _recordSessionStart());
      case ShareMode.off:
        break;
    }
  }

  /// Counts only sessions that actually started, so a failed attempt does not
  /// unlock the "this session" stats row.
  void _recordSessionStart() {
    final settings = ref.read(appSettingProvider.notifier);
    settings.setUnboundedSessionCount(
      ref.read(appSettingProvider).unboundedSessionCount + 1,
    );
  }

  Future<void> _stop(WidgetRef widgetRef) async {
    final result = switch (state.mode) {
      ShareMode.smc =>
        await widgetRef
            .read(radianceSettingsProvider.notifier)
            .setPeerProxy(false),
      ShareMode.unbounded =>
        await widgetRef.read(lanternServiceProvider).setUnboundedEnabled(false),
      ShareMode.off => right<Failure, Unit>(unit),
    };
    if (!ref.mounted) return;
    result.fold(
      (err) {
        // The backend is still sharing, so keep saying so; the next toggle
        // retries the stop.
        appLogger.error('Stop sharing failed: ${err.error}');
        state = state.copyWith(errorMessage: err.error);
      },
      (_) {
        _stopEventSubscription();
        state = ShareState(totalCount: state.totalCount, relay: _idleRelay());
        _persistRelay(force: true);
      },
    );
  }

  /// Switches a failed SmC session to Unbounded. radiance has already rolled
  /// its peer-share setting back, so only the local mode and broflake remain.
  Future<void> _fallbackToUnbounded(WidgetRef widgetRef, String? reason) async {
    if (state.mode == ShareMode.unbounded) return;
    // A helper start may have lost its eligibility while SmC registered.
    final guard = _startGuard;
    if (guard != null && !guard()) {
      _stopEventSubscription();
      state = ShareState(totalCount: state.totalCount, relay: _idleRelay());
      _persistRelay(force: true);
      return;
    }
    _changes++;
    try {
      _stopEventSubscription();
      state = ShareState(
        active: true,
        mode: ShareMode.unbounded,
        totalCount: state.totalCount,
        fallbackReason: (reason?.isNotEmpty ?? false) ? reason : null,
        relay: state.relay.newSession(),
      );
      final result = await widgetRef
          .read(lanternServiceProvider)
          .setUnboundedEnabled(true);
      if (!ref.mounted) return;
      result.fold((err) {
        appLogger.error(
          'SmC→Unbounded fallback: setUnboundedEnabled failed: ${err.error}',
        );
        _failOff(err.error);
      }, (_) => _recordSessionStart());
    } finally {
      _changes--;
    }
  }

  void _failOff(String message) {
    _stopEventSubscription();
    state = ShareState(
      totalCount: state.totalCount,
      phase: SharePhase.error,
      errorMessage: message,
      relay: _idleRelay(),
    );
    _persistRelay(force: true);
  }

  // ─── Backend events ────────────────────────────────────────────────────────

  /// Unbounded and SmC snapshots arrive for the process lifetime, regardless
  /// of mode.
  void _handleUnboundedEvent(AppEvent event) {
    if (event.eventType == 'peer-snapshot') {
      try {
        _applyPeerSnapshot(jsonDecode(event.message) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('share-my-connection: bad peer snapshot: $e');
      }
      return;
    }
    if (event.eventType == 'unbounded-unavailable') {
      if (!_changing && state.mode == ShareMode.unbounded) {
        _clearPeers();
        state = state.copyWith(
          unboundedRunning: false,
          activeCount: 0,
          relay: _idleRelay(),
        );
        _persistRelay(force: true);
      } else if (!_changing && state.mode == ShareMode.smc) {
        // Peer snapshots stop too, so the last speed would otherwise stay up.
        state = state.copyWith(relay: _idleRelay());
      }
      return;
    }
    if (event.eventType != 'unbounded-snapshot') return;
    try {
      _applyUnboundedSnapshot(
        jsonDecode(event.message) as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('share-my-connection: bad snapshot: $e');
    }
  }

  /// SmC-only: peer-status and peer-connection events from radiance.
  void _startEventSubscription(WidgetRef widgetRef) {
    _stopEventSubscription();
    if (state.mode != ShareMode.smc) return;
    _appEventSub = widgetRef
        .read(lanternServiceProvider)
        .watchAppEvents()
        .listen((event) {
          if (event.eventType == 'peer-status') {
            _handlePeerStatus(event.message, widgetRef);
          } else if (event.eventType == 'peer-connection' &&
              state.mode == ShareMode.smc) {
            _handlePeerConnection(event.message);
          }
        });
  }

  void _stopEventSubscription() {
    _appEventSub?.cancel();
    _appEventSub = null;
    _clearPeers();
  }

  void _handlePeerStatus(String message, WidgetRef widgetRef) {
    // A status event describes SmC only. Dropping it in other modes keeps a
    // late phase=error from overwriting a fallback that already happened.
    if (state.mode != ShareMode.smc) return;
    try {
      final payload = jsonDecode(message) as Map<String, dynamic>;
      final phase = SharePhase.fromWire(payload['phase'] as String?);
      final errMsg = payload['error'] as String?;
      if (phase == SharePhase.error) {
        appLogger.info(
          'SmC start failed, falling back to Unbounded: ${errMsg ?? ""}',
        );
        unawaited(_fallbackToUnbounded(widgetRef, errMsg));
        return;
      }
      if (phase == SharePhase.idle) {
        _stopEventSubscription();
        state = ShareState(totalCount: state.totalCount, relay: state.relay);
        return;
      }
      state = state.copyWith(
        phase: phase,
        errorMessage: (errMsg != null && errMsg.isNotEmpty) ? errMsg : null,
      );
    } catch (e) {
      debugPrint('share-my-connection: bad peer-status event: $e');
    }
  }

  /// Payload is `{state: +1|-1, source: "ip:port"}`.
  void _handlePeerConnection(String message) {
    try {
      final payload = jsonDecode(message) as Map<String, dynamic>;
      final eventState = (payload['state'] as num?)?.toInt() ?? 0;
      final ip = ((payload['source'] as String?) ?? '').hostAddress;
      if (ip.isEmpty) return;

      if (eventState == 1) {
        final existing = _peerArcs[ip];
        if (existing != null) {
          existing.streamCount++;
          return;
        }
        final arc = _PeerArc(_workerSeq++);
        _peerArcs[ip] = arc;
        final newTotal = state.totalCount + 1;
        state = state.copyWith(
          activeCount: state.activeCount + 1,
          totalCount: newTotal,
        );
        ref.read(appSettingProvider.notifier).setUnboundedTotalHelped(newTotal);
        unawaited(_resolveAndEmit(ip, arc));
        // Bytes follow from SmC relay snapshots; this adds the person.
        unawaited(_attributeToCountry(ip, (down: 0, up: 0), arrived: true));
      } else if (eventState == -1) {
        final entry = _peerArcs[ip];
        if (entry == null) return;
        entry.streamCount--;
        if (entry.streamCount > 0) return;
        _peerArcs.remove(ip);
        _emitDisconnected(entry);
        state = state.copyWith(activeCount: max(0, state.activeCount - 1));
      }
    } catch (e) {
      // debugPrint on purpose: appLogger.error surfaces as a toast in some
      // debug builds, and one bad wire event should not escalate that far.
      debugPrint('share-my-connection: bad peer-connection event: $e');
    }
  }

  /// Reconciles peers against a full Unbounded snapshot: removes arcs for
  /// peers that vanished, adds arcs for new ones, and folds completed
  /// arrivals into the lifetime total.
  void _applyUnboundedSnapshot(Map<String, dynamic> snapshot) {
    if (_changing) return;
    if (state.mode == ShareMode.smc) {
      // Unbounded can still flush bytes from a session that stopped just
      // before SmC started. Count them without touching SmC's state.
      final markBefore = _unboundedFeed.counters.watermark;
      state = state.copyWith(
        relay: _applyRelayCounters(
          snapshot,
          feed: _unboundedFeed,
          epoch: snapshot['epoch'] as String,
          present: const {},
          running: false,
          updateSpeed: false,
        ),
      );
      // Saved at once only when Unbounded's own counters moved: SmC's
      // snapshots mark the stats dirty every second, and forcing on every
      // idle Unbounded snapshot would bypass the throttle for them.
      _persistRelay(force: _unboundedFeed.counters.watermark != markBefore);
      return;
    }
    final enabled = snapshot['enabled'] as bool;
    final running = snapshot['running'] as bool;
    final peers = (snapshot['peers'] as List).cast<String>();
    final counts = <String, int>{};
    if (enabled && running) {
      for (final source in peers) {
        final ip = source.hostAddress;
        if (ip.isNotEmpty) counts.update(ip, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    final replay = !_hasUnboundedSnapshot;
    _hasUnboundedSnapshot = true;
    for (final ip in _peerArcs.keys.toList()) {
      if (counts.containsKey(ip)) continue;
      _emitDisconnected(_peerArcs.remove(ip)!);
    }
    for (final entry in counts.entries) {
      var arc = _peerArcs[entry.key];
      if (arc == null) {
        arc = _PeerArc(_workerSeq++);
        _peerArcs[entry.key] = arc;
        unawaited(_resolveAndEmit(entry.key, arc, isReplay: replay));
      }
      arc.streamCount = entry.value;
    }

    // Arrivals are a per-epoch counter; a new epoch means the backend
    // restarted, so only same-epoch deltas count.
    final epoch = snapshot['epoch'] as String;
    final arrivals = (snapshot['arrivals'] as num).toInt();
    final total =
        state.totalCount +
        (_snapshotEpoch == epoch ? max<int>(0, arrivals - _lastArrivals) : 0);
    _snapshotEpoch = epoch;
    _lastArrivals = arrivals;
    state = state.copyWith(
      active: enabled,
      mode: enabled ? ShareMode.unbounded : ShareMode.off,
      unboundedRunning: enabled && running,
      activeCount: counts.length,
      totalCount: total,
      relay: _applyRelayCounters(
        snapshot,
        feed: _unboundedFeed,
        epoch: epoch,
        present: counts.keys.toSet(),
        running: enabled && running,
      ),
    );
    if (total != ref.read(appSettingProvider).unboundedTotalHelped) {
      ref.read(appSettingProvider.notifier).setUnboundedTotalHelped(total);
    }
    // A stopped backend's final counters may be the last this app sees.
    _persistRelay(force: !(enabled && running));
  }

  /// Folds an SmC relay snapshot's byte counters into the relay stats. Applied
  /// in every mode, so bytes a session relays just before it stops still
  /// count, but only drives the speed while SmC is the active mode. People
  /// come from peer-connection events, so the snapshot's arrivals are not
  /// counted again.
  void _applyPeerSnapshot(Map<String, dynamic> snapshot) {
    if (_changing) return;
    final smc = state.mode == ShareMode.smc;
    state = state.copyWith(
      relay: _applyRelayCounters(
        snapshot,
        feed: _peerFeed,
        epoch: (snapshot['epoch'] as String?) ?? '',
        present: const {},
        running: smc && ((snapshot['running'] as bool?) ?? false),
        updateSpeed: smc,
        countArrivals: false,
      ),
    );
    _persistRelay();
  }

  // ─── Relay stats ───────────────────────────────────────────────────────────

  /// Folds a snapshot's byte counters into session and lifetime totals and
  /// the smoothed speed. Per-country totals follow asynchronously, once each
  /// peer's country is resolved.
  RelayStats _applyRelayCounters(
    Map<String, dynamic> snapshot, {
    required _RelayFeed feed,
    required String epoch,
    required Set<String> present,
    required bool running,
    bool updateSpeed = true,
    bool countArrivals = true,
  }) {
    final available = snapshot.containsKey('bytesDown');
    final peerBytes = <String, ByteCounts>{};
    RelayCounterTracker.parsePeerBytes(snapshot['peerBytes']).forEach((
      source,
      counts,
    ) {
      final ip = source.hostAddress;
      if (ip.isEmpty) return;
      final prev = peerBytes[ip];
      peerBytes[ip] = prev == null
          ? counts
          : (down: prev.down + counts.down, up: prev.up + counts.up);
    });
    final markBefore = feed.counters.watermark;
    final delta = feed.counters.apply(
      epoch: epoch,
      down: (snapshot['bytesDown'] as num?)?.toInt() ?? 0,
      up: (snapshot['bytesUp'] as num?)?.toInt() ?? 0,
      peers: peerBytes,
      present: present,
    );

    final now = clock();
    final previousSampleAt = feed.lastSampleAt;
    feed.lastSampleAt = now;
    var relay = state.relay;
    var speedDown = relay.speedDown;
    var speedUp = relay.speedUp;
    if (!updateSpeed) {
      // Another mode owns the speed.
    } else if (!running || !available) {
      speedDown = 0;
      speedUp = 0;
    } else if (!delta.reset && previousSampleAt != null) {
      final seconds = now.difference(previousSampleAt).inMicroseconds / 1e6;
      if (seconds > 0) {
        speedDown += (delta.down / seconds - speedDown) * _speedSmoothing;
        speedUp += (delta.up / seconds - speedUp) * _speedSmoothing;
      }
    }
    relay = relay.copyWith(
      available: updateSpeed ? available : relay.available,
      sessionDown: relay.sessionDown + delta.down,
      sessionUp: relay.sessionUp + delta.up,
      lifetimeDown: relay.lifetimeDown + delta.down,
      lifetimeUp: relay.lifetimeUp + delta.up,
      speedDown: speedDown,
      speedUp: speedUp,
    );
    // A moved watermark is saved even without bytes to add, so the next app
    // run resumes from it instead of taking another baseline.
    if (delta.down > 0 ||
        delta.up > 0 ||
        feed.counters.watermark != markBefore) {
      _relayDirty = true;
    }

    final arrivals = countArrivals ? delta.arrivals : const <String>{};
    for (final ip in {...delta.peers.keys, ...arrivals}) {
      unawaited(
        _attributeToCountry(
          ip,
          delta.peers[ip] ?? (down: 0, up: 0),
          arrived: arrivals.contains(ip),
        ),
      );
    }
    return relay;
  }

  Future<void> _attributeToCountry(
    String ip,
    ByteCounts bytes, {
    required bool arrived,
  }) async {
    PeerGeo geo;
    try {
      geo = await GeoLookupService.peerLookup(ip);
    } catch (_) {
      geo = PeerGeo.unknown;
    }
    if (!ref.mounted) return;
    final code = geo.countryCode.isEmpty
        ? RelayCountryStats.unknownCode
        : geo.countryCode;
    final countries = Map.of(state.relay.countries);
    countries[code] = (countries[code] ?? RelayCountryStats(code: code)).add(
      name: geo.countryName,
      down: bytes.down,
      up: bytes.up,
      people: arrived ? 1 : 0,
    );
    state = state.copyWith(relay: state.relay.copyWith(countries: countries));
    _relayDirty = true;
    _persistRelay();
  }

  RelayStats _idleRelay() => state.relay.copyWith(speedDown: 0, speedUp: 0);

  /// AppSetting writes log and re-serialize every setting, so lifetime relay
  /// stats are saved at most every [relayPersistInterval] unless [force]d.
  /// A throttled save is deferred, not dropped, so late country lookups are
  /// saved even when no further snapshot arrives.
  void _persistRelay({bool force = false}) {
    if (!_relayDirty) return;
    final now = clock();
    final last = _lastRelayPersistAt;
    if (!force && last != null) {
      final wait = relayPersistInterval - now.difference(last);
      if (wait > Duration.zero) {
        _relayPersistTimer ??= Timer(wait, () {
          _relayPersistTimer = null;
          if (ref.mounted) _persistRelay(force: true);
        });
        return;
      }
    }
    _relayPersistTimer?.cancel();
    _relayPersistTimer = null;
    _relayDirty = false;
    _lastRelayPersistAt = now;
    final relay = state.relay;
    ref
        .read(appSettingProvider.notifier)
        .setUnboundedRelayStats(
          bytesDown: relay.lifetimeDown,
          bytesUp: relay.lifetimeUp,
          countries: relay.countries,
          mark: _unboundedFeed.counters.watermark,
          peerMark: _peerFeed.counters.watermark,
        );
  }

  // ─── Peer arcs ─────────────────────────────────────────────────────────────

  Future<void> _resolveAndEmit(
    String ip,
    _PeerArc arc, {
    bool isReplay = false,
  }) async {
    PeerGeo geo;
    try {
      geo = await GeoLookupService.peerLookup(ip);
    } catch (_) {
      geo = PeerGeo.unknown;
    }
    if (_eventController.isClosed) return;
    // A lookup from an earlier session must not add an arc to its replacement.
    if (!identical(_peerArcs[ip], arc)) return;
    // Unresolved peers still count, but no wrong-country arc is drawn.
    if (geo.countryCode.isEmpty) return;
    arc.geo = geo;
    _emitConnected(arc, geo, isReplay: isReplay);
  }

  void _emitConnected(_PeerArc arc, PeerGeo geo, {required bool isReplay}) {
    _eventController.add(
      ActionModeConnectionEvent(
        state: 1,
        workerIdx: arc.workerIdx,
        countryName: geo.countryName,
        countryCode: geo.countryCode,
        coordinates: geo.coordinates,
        isReplay: isReplay,
      ),
    );
  }

  /// Emits -1 only for arcs the globe has seen (geo resolved).
  void _emitDisconnected(_PeerArc arc) {
    if (arc.geo == null) return;
    _eventController.add(
      ActionModeConnectionEvent(state: -1, workerIdx: arc.workerIdx),
    );
  }

  /// Backend shutdown can suppress disconnect events, so arcs are removed
  /// explicitly.
  void _clearPeers() {
    _hasUnboundedSnapshot = false;
    for (final arc in _peerArcs.values) {
      _emitDisconnected(arc);
    }
    _peerArcs.clear();
  }

  // ─── Consent dialog ────────────────────────────────────────────────────────

  Future<bool> _showConsentDialog(BuildContext context) async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ShareConsentDialog(),
    );
    if (accepted != true) return false;
    await _storage.setString(_consentAckKey, '1');
    return true;
  }
}

class _PeerArc {
  _PeerArc(this.workerIdx) : streamCount = 1;
  final int workerIdx;
  int streamCount;
  // Resolved async after the first +1; no arc is emitted until then.
  PeerGeo? geo;
}

/// A snapshot source's counter tracker and the time of its last sample, from
/// which its speed is measured.
class _RelayFeed {
  final counters = RelayCounterTracker();
  DateTime? lastSampleAt;
}
