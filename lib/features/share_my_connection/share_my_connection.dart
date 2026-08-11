// Share My Connection — unified screen for both Unbounded and the
// samizdat-over-UPnP "Share My Connection" modes:
//   - Toggle ON triggers a real UPnP / IGD probe via the lantern
//     service (FFI on desktop, MethodChannel on mobile).
//   - If UPnP works AND the user accepts the SmC disclosure, run SmC mode
//     (calls into radiance via the existing radianceSettingsProvider
//     setPeerProxy path).
//   - Otherwise fall back to Unbounded mode.
//   - Globe animates connection arcs from peer-connection FlutterEvents
//     streamed up from radiance.

import 'dart:async';
import 'dart:convert';
import 'dart:math' show max, min;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_earth_globe/flutter_earth_globe.dart';
import 'package:flutter_earth_globe/flutter_earth_globe_controller.dart';
import 'package:flutter_earth_globe/globe_coordinates.dart';
import 'package:flutter_earth_globe/point.dart';
import 'package:flutter_earth_globe/point_connection.dart';
import 'package:flutter_earth_globe/point_connection_style.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/unbounded_connection_event.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/core/services/geo_lookup_service.dart';
import 'package:lantern/core/services/injection_container.dart' show sl;
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/core/widgets/switch_button.dart';
import 'package:lantern/features/home/provider/radiance_settings_providers.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

// ─── State ───────────────────────────────────────────────────────────────────

/// Which underlying protocol the user is contributing through.
///
///   off       — toggle is off / probe in flight
///   unbounded — broflake / WebRTC widget proxy (works on any network)
///   smc       — samizdat-over-UPnP "Share My Connection" (higher capability,
///               higher risk; gated on a one-time disclosure)
enum ShareMode { off, unbounded, smc }

/// Lifecycle phase for SmC mode, sourced from radiance peer.Status.Phase
/// via the `peer-status` FlutterEvent. Stable strings — must stay in
/// sync with radiance/peer/peer.go's Phase constants.
///
///   idle           — nothing running
///   mappingPort    — UPnP / manual port mapping in flight
///   detectingIp    — public-IP detection
///   registering    — POST /v1/peer/register against lantern-cloud
///   startingProxy  — libbox samizdat inbound coming up
///   verifying      — POST /v1/peer/verify, lantern-cloud is dialing back
///   serving        — peer is live and assignable to censored clients
///   stopping       — teardown in progress
///   error          — Start failed; SharePhase.errorMessage holds the cause
enum SharePhase {
  idle,
  mappingPort,
  detectingIp,
  registering,
  startingProxy,
  verifying,
  serving,
  stopping,
  error;

  static SharePhase fromWire(String? s) => switch (s) {
        'mapping_port' => SharePhase.mappingPort,
        'detecting_ip' => SharePhase.detectingIp,
        'registering' => SharePhase.registering,
        'starting_proxy' => SharePhase.startingProxy,
        'verifying' => SharePhase.verifying,
        'serving' => SharePhase.serving,
        'stopping' => SharePhase.stopping,
        'error' => SharePhase.error,
        _ => SharePhase.idle,
      };
}

class ShareState {
  final bool active;
  final bool probing;
  final ShareMode mode;
  final int activeCount;
  final int totalCount;
  // SmC-only: granular Start/Stop phase from radiance peer.Status. For
  // Unbounded mode this stays SharePhase.idle (no equivalent staged
  // lifecycle on the broflake side yet).
  final SharePhase phase;
  final String? errorMessage;

  const ShareState({
    this.active = false,
    this.probing = false,
    this.mode = ShareMode.off,
    this.activeCount = 0,
    this.totalCount = 0,
    this.phase = SharePhase.idle,
    this.errorMessage,
  });

  ShareState copyWith({
    bool? active,
    bool? probing,
    ShareMode? mode,
    int? activeCount,
    int? totalCount,
    SharePhase? phase,
    // Sentinel-defaulted so callers can distinguish "leave alone" (omit
    // the argument) from "clear it" (pass null explicitly). The naive
    // `String? errorMessage` + `?? this.errorMessage` pattern conflates
    // the two and leaves stale error text wedged in state forever — the
    // next time a phase transition lands in error, the wrong message
    // would get re-rendered.
    Object? errorMessage = _unsetErrorMessage,
  }) =>
      ShareState(
        active: active ?? this.active,
        probing: probing ?? this.probing,
        mode: mode ?? this.mode,
        activeCount: activeCount ?? this.activeCount,
        totalCount: totalCount ?? this.totalCount,
        phase: phase ?? this.phase,
        errorMessage: identical(errorMessage, _unsetErrorMessage)
            ? this.errorMessage
            : errorMessage as String?,
      );
}

// Sentinel for ShareState.copyWith. Has to be a const value distinct
// from any String? a caller might supply (including null), hence the
// private class — `const Object()` instances can be canonicalized to
// the same identity as another bare Object literal.
class _UnsetErrorMessage {
  const _UnsetErrorMessage();
}
const _unsetErrorMessage = _UnsetErrorMessage();

// ─── Notifier (mock-backed) ──────────────────────────────────────────────────

/// Extracts the IP from a peer source string. Handles the four shapes
/// the Go side might emit:
///   - bracketed IPv6 host:port  `[2001:db8::1]:443` → `2001:db8::1`
///   - bare IPv6 (no port)       `2001:db8::1`       → `2001:db8::1`
///   - IPv4 host:port            `203.0.113.5:443`   → `203.0.113.5`
///   - bare IPv4 (no port)       `203.0.113.5`       → `203.0.113.5`
/// Returns an empty string if input is empty.
String _extractIP(String source) {
  if (source.isEmpty) return '';
  // Bracketed IPv6 host:port — Uri parser strips the brackets and
  // returns the inner host. This is the only shape where the
  // synthesized-scheme URI parse is unambiguous.
  if (source.startsWith('[')) {
    final uri = Uri.tryParse('p://$source');
    final host = uri?.host ?? '';
    if (host.isNotEmpty) return host;
    return ''; // malformed bracket
  }
  final first = source.indexOf(':');
  if (first < 0) return source; // bare IPv4 (no port)
  // Multiple colons + no brackets = bare IPv6. Bare IPv6 is
  // emitted by some broflake paths that don't bracket-format
  // addresses; we accept it as-is rather than truncating at the
  // last ':' which would mangle the address.
  if (first != source.lastIndexOf(':')) return source;
  // Exactly one ':' — IPv4 host:port.
  return source.substring(0, first);
}

class _PeerArc {
  _PeerArc(this.workerIdx) : streamCount = 1;
  final int workerIdx;
  int streamCount;
  // Geo is resolved async after the first +1 lands. Until then the peer is
  // tracked but no arc is emitted — avoids a flash of "unknown" arcs.
  PeerGeo? geo;
}

class ShareNotifier extends Notifier<ShareState> {
  // Consent ack persists across launches via LocalStorageService
  // (SharedPreferences). Key-presence is the signal — the value is
  // arbitrary. Cleared by deleteAll() in the existing reset flow.
  static const _consentAckKey = 'share_consent_acked';
  // Anyone who accepted the old SmC-only disclosure consented to the exit-node
  // case, which is the stronger of the two, so that ack carries forward rather
  // than re-prompting them.
  static const _legacySmcAckKey = 'smc_disclosure_acked';
  LocalStorageService get _storage => sl<LocalStorageService>();
  bool get _consentAcked =>
      _storage.containsKey(_consentAckKey) ||
      _storage.containsKey(_legacySmcAckKey);
  Future<void> _persistConsentAck() => _storage.setString(_consentAckKey, '1');

  /// Prompts for sharing consent if it hasn't been given, and reports whether
  /// sharing may proceed. Safe to call when consent already exists — it
  /// short-circuits without showing anything.
  ///
  /// Both modes route other people's traffic through the user's connection, so
  /// one disclosure covers both; it is worded for the worse case (SmC, where
  /// the user's own IP is the exit) because the mode isn't known until the
  /// UPnP probe runs, after consent.
  Future<bool> ensureConsent(BuildContext context) async {
    if (_consentAcked) return true;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ShareConsentDialog(),
    );
    if (accepted != true) return false;
    await _persistConsentAck();
    return true;
  }

  StreamSubscription? _appEventSub;
  int _workerSeq = 0;
  // Per-peer arc + active-stream count. samizdat multiplexes many H2 streams
  // over one TCP conn, all sharing the same RemoteAddr — ref-count so the arc
  // persists until the peer's LAST stream closes, not its first.
  final Map<String, _PeerArc> _peerArcs = {};

  final _eventController =
      StreamController<UnboundedConnectionEvent>.broadcast();
  Stream<UnboundedConnectionEvent> get connectionEvents =>
      _eventController.stream;

  @override
  ShareState build() {
    // Keep the notifier alive for the process lifetime. Without this,
    // navigating away from the screen disposes the notifier; re-entry
    // calls build() again and resets state to mode=off / active=false
    // even when SmC or Unbounded is still actually running on the
    // backend. The next toggle would then try to re-enable an
    // already-enabled setting, and the user loses visibility into
    // the active counter and the granular peer-status phase.
    //
    // ref.onDispose stays registered for explicit Stop/Disable paths
    // (provider container reset, hot reload, etc.) so the event
    // subscription and stream controller still get cleaned up when
    // it does actually happen.
    ref.keepAlive();
    ref.onDispose(() {
      _stopEventSubscription();
      _eventController.close();
    });
    // Seed totalCount from the persisted lifetime running total so the
    // "Total people helped to date" stat survives app restarts. New
    // arrivals (line further down) increment both ShareState.totalCount
    // and the persisted value via setUnboundedTotalHelped.
    final persistedTotal =
        ref.read(appSettingProvider).unboundedTotalHelped;
    return ShareState(totalCount: persistedTotal);
  }

  /// Toggle entry point. Caller passes its BuildContext so we can show the
  /// disclosure modal inline, and a WidgetRef so we can drive the radiance
  /// peer-share toggle.
  ///
  /// Resolution order on enable:
  ///   1. If the user has set a manual port in Advanced settings, that
  ///      is an explicit opt-in — go straight to SmC mode. No UPnP
  ///      probe, no disclosure (user already crossed that line by
  ///      configuring the port forward on their router).
  ///   2. Otherwise probe UPnP. If UPnP works AND the user accepts
  ///      the SmC disclosure, run SmC. Decline → Unbounded.
  ///   3. UPnP unavailable → Unbounded fallback.
  Future<void> toggle(BuildContext context, WidgetRef widgetRef) async {
    if (state.active || state.probing) {
      await _stop(widgetRef);
      return;
    }

    // Consent gates every start path, before the mode is even known.
    if (!await ensureConsent(context)) {
      state = state.copyWith(probing: false);
      return;
    }

    state = state.copyWith(probing: true);

    // Manual port forward skips the UPnP probe: configuring a port by hand is
    // an explicit request for the residential-IP path.
    final manualPortRes =
        await widgetRef.read(lanternServiceProvider).getPeerManualPort();
    final manualPort = manualPortRes.fold((_) => 0, (p) => p);
    if (manualPort > 0) {
      await _start(widgetRef, ShareMode.smc);
      return;
    }

    // Real UPnP probe via FFI / MethodChannel. probeUPnP runs IGD
    // discovery on the local network and returns true when a usable
    // gateway is reachable. Blocks up to ~6 seconds on the M-SEARCH
    // multicast wait — long enough that the "Probing your network…"
    // status from copyWith(probing: true) above is visible to the
    // user. Any failure (no IGD, timeout, FFI / channel error) is
    // treated as "UPnP unavailable" → fall back to Unbounded.
    final probeRes =
        await widgetRef.read(lanternServiceProvider).probeUPnP();
    final upnpAvailable = probeRes.fold((_) => false, (v) => v);
    if (!upnpAvailable) {
      await _start(widgetRef, ShareMode.unbounded);
      return;
    }

    await _start(widgetRef, ShareMode.smc);
  }

  /// Programmatic entry point used by the Home shell's auto-enable
  /// listener (VPN-connected → Unbounded on) and by the
  /// "Auto-enable Unbounded" Settings toggle.
  ///
  /// Always starts Unbounded mode regardless of UPnP capability or
  /// manual-port configuration. SmC would make the user's device a
  /// residential exit, and this path has no UI to disclose that, so it stays
  /// on the relayed surface even for a user who has consented.
  ///
  /// No-ops if already active or in flight, or if consent has never been
  /// given — this path cannot prompt, so refusing to start is the only safe
  /// direction. Consent is collected by toggle() or by enabling auto-start in
  /// Unbounded Settings, both of which have a BuildContext.
  Future<void> autoStart(WidgetRef widgetRef) async {
    if (state.active || state.probing) return;
    if (!_consentAcked) return;
    state = state.copyWith(probing: true);
    await _start(widgetRef, ShareMode.unbounded);
  }

  Future<void> _start(WidgetRef widgetRef, ShareMode mode) async {
    state = ShareState(
      active: true,
      probing: false,
      mode: mode,
      activeCount: 0,
      // Preserve the running total across off→on cycles so toggling
      // doesn't reset the user's lifetime count.
      totalCount: state.totalCount,
    );
    _startEventSubscription(widgetRef);
    switch (mode) {
      case ShareMode.smc:
        // Flip the radiance peer-proxy setting; LocalBackend.PatchSettings
        // routes that into peer.Client.Start, which spins up the UPnP map
        // (or honours PeerManualPortKey), registers with lantern-cloud,
        // runs the samizdat inbound, and (via the lantern-box peerconn
        // listener) emits ConnectionEvents that ride the radiance event
        // bus → core.go listenPeerConnectionEvents → FlutterEvent → our
        // Dart subscription.
        //
        // Failures AFTER peer.Client.Start surface via a phase=error
        // StatusEvent that _handlePeerStatus turns into a terminal-
        // state reset (mode=off, phase=error). Failures BEFORE
        // Start (IPC error, MissingPluginException, core not
        // initialized) don't go through that path, so check the
        // setPeerProxy Either here and revert UI state to
        // mode=off, phase=error directly.
        final smcRes = await widgetRef
            .read(radianceSettingsProvider.notifier)
            .setPeerProxy(true);
        smcRes.fold(
          (err) {
            appLogger.error('SmC setPeerProxy failed: ${err.error}');
            _stopEventSubscription();
            state = ShareState(
              active: false,
              probing: false,
              mode: ShareMode.off,
              activeCount: 0,
              // Preserve lifetime totalCount across a failed Start — the
              // persisted "Total people helped to date" stat is set
              // independent of the active session's outcome.
              totalCount: state.totalCount,
              phase: SharePhase.error,
              errorMessage: err.error,
            );
          },
          (_) => null,
        );
        break;
      case ShareMode.unbounded:
        // Unbounded is the broflake / WebRTC widget-proxy mode. Local
        // opt-in only — actual run state also depends on the server's
        // Features[unbounded] flag and supplied UnboundedConfig. When
        // running, broflake's OnConnectionChange callback emits
        // unbounded.ConnectionEvent → forwarded by lantern-core as the
        // same EventTypePeerConnection FlutterEvent the SmC path uses,
        // so this Dart subscription consumes both protocols uniformly.
        //
        // Unbounded has no equivalent of the peer.Client phase=error
        // StatusEvent that the SmC path leans on for failure recovery,
        // so check the Either return here and revert to off if the
        // setting flip failed (core not initialized, MethodChannel
        // failure, etc.) — otherwise the UI sticks at "Active" while
        // nothing actually started.
        final res = await widgetRef
            .read(lanternServiceProvider)
            .setUnboundedEnabled(true);
        res.fold(
          (err) {
            appLogger.error('setUnboundedEnabled failed: ${err.error}');
            _stopEventSubscription();
            state = ShareState(
              active: false,
              probing: false,
              mode: ShareMode.off,
              activeCount: 0,
              // Preserve lifetime totalCount across a failed Start (see
              // matching comment in the SmC branch above).
              totalCount: state.totalCount,
              phase: SharePhase.error,
              errorMessage: err.error,
            );
          },
          (_) => null,
        );
        break;
      case ShareMode.off:
        break;
    }
  }

  Future<void> _stop(WidgetRef widgetRef) async {
    _stopEventSubscription();
    final priorMode = state.mode;
    // Preserve totalCount across toggle-off (same reason as _start —
    // user's lifetime count shouldn't reset on a toggle cycle).
    state = ShareState(totalCount: state.totalCount);
    switch (priorMode) {
      case ShareMode.smc:
        await widgetRef
            .read(radianceSettingsProvider.notifier)
            .setPeerProxy(false);
        break;
      case ShareMode.unbounded:
        await widgetRef
            .read(lanternServiceProvider)
            .setUnboundedEnabled(false);
        break;
      case ShareMode.off:
        break;
    }
  }

  // ── Live connection event source ───────────────────────────────────────────
  // Subscribes to the existing FFI app-event stream (the same one
  // AppEventNotifier uses for config / server-location / data-cap events)
  // and filters for type=='peer-connection'. Each event's message is
  // {state: +1|-1, source: "ip:port"} originally emitted from the
  // lantern-box samizdat inbound via the peerconn listener registry, then
  // rebroadcast by lantern-core/core.go listenPeerConnectionEvents.
  //
  // No local sockets, no fixed ports — the bridge rides on Dart api_dl,
  // which is the same channel server-location updates and data-cap events
  // already use.

  void _startEventSubscription(WidgetRef widgetRef) {
    _peerArcs.clear();
    _appEventSub = widgetRef
        .read(lanternServiceProvider)
        .watchAppEvents()
        .listen((event) {
      if (event.eventType == 'peer-status') {
        _handlePeerStatus(event.message, widgetRef);
        return;
      }
      if (event.eventType != 'peer-connection') return;
      try {
        final payload = jsonDecode(event.message) as Map<String, dynamic>;
        final eventState = (payload['state'] as num?)?.toInt() ?? 0;
        final source = (payload['source'] as String?) ?? '';
        // Globe only cares about the IP — strip ":port". Handle three
        // forms the Go side might emit:
        //   IPv4 host:port          → "203.0.113.5:443"
        //   IPv6 bracketed host:port → "[2001:db8::1]:443"
        //   bare IP (no port)        → "2001:db8::1" or "203.0.113.5"
        // A naive split(':').first works for the first form but
        // mangles IPv6 ("[2001" or "2001"). Use Uri.tryParse against
        // the synthesized "scheme://source" form to do host extraction
        // properly, with a bare-IP fallback for cases where source has
        // no port appended.
        final ip = _extractIP(source);
        if (ip.isEmpty) return;

        if (eventState == 1) {
          final existing = _peerArcs[ip];
          if (existing != null) {
            existing.streamCount++;
            return;
          }
          final widx = _workerSeq++;
          final arc = _PeerArc(widx);
          _peerArcs[ip] = arc;
          final newTotal = state.totalCount + 1;
          state = state.copyWith(
            activeCount: state.activeCount + 1,
            totalCount: newTotal,
          );
          // Persist so the "Total people helped to date" stat
          // survives restarts. Reached only on first-time-seen IPs —
          // the dedup at _peerArcs[ip] above returns early for repeat
          // events on an existing connection (liveness probes, stream
          // reattaches), so this is one write per unique peer-arrival,
          // not per peer-connection event.
          ref
              .read(appSettingProvider.notifier)
              .setUnboundedTotalHelped(newTotal);
          // Resolve country async. Emit the +1 only after lookup so the
          // globe can render the arc at the right coords and the UI can
          // surface the country name in the connection banner.
          unawaited(_resolveAndEmit(ip, arc));
        } else if (eventState == -1) {
          final entry = _peerArcs[ip];
          if (entry == null) return;
          entry.streamCount--;
          if (entry.streamCount > 0) return;
          _peerArcs.remove(ip);
          // Only emit -1 if we already emitted a +1 for this peer (i.e.
          // the geo lookup completed). Otherwise the globe never saw it
          // and a -1 with no preceding +1 would just be noise.
          if (entry.geo != null) {
            _eventController.add(UnboundedConnectionEvent(
              state: -1,
              workerIdx: entry.workerIdx,
              addr: '',
            ));
          }
          state = state.copyWith(
            activeCount: max(0, state.activeCount - 1),
          );
        }
      } catch (e) {
        // Malformed event — log without bringing down the listener.
        // debugPrint is intentional: appLogger.error would surface as
        // a user-visible error toast in some debug builds, and a
        // single bad event from the wire shouldn't escalate that
        // far. The listener stays subscribed so subsequent
        // well-formed events still arrive.
        debugPrint('share-my-connection: bad peer-connection event: $e');
      }
    });
  }

  Future<void> _resolveAndEmit(String ip, _PeerArc arc) async {
    PeerGeo geo;
    try {
      geo = await GeoLookupService.peerLookup(ip);
    } catch (_) {
      geo = PeerGeo.unknown;
    }
    // The notifier could have been disposed during the await (provider
    // teardown closes _eventController). Guard before touching it so
    // a late lookup completion doesn't throw "Bad state: Cannot add
    // event after closing" on the disposed sink.
    if (_eventController.isClosed) return;
    // Peer may have disconnected before the lookup returned. The map
    // entry's identity (workerIdx) is the cheapest check.
    final current = _peerArcs[ip];
    if (current == null || current.workerIdx != arc.workerIdx) return;
    // Skip arcs we couldn't geo-locate. The peer is still counted in
    // activeCount, but we don't draw a wrong-country arc.
    if (geo.countryCode.isEmpty) return;
    arc.geo = geo;
    _eventController.add(UnboundedConnectionEvent(
      state: 1,
      workerIdx: arc.workerIdx,
      addr: ip,
      countryName: geo.countryName,
      countryCode: geo.countryCode,
      flagEmoji: geo.flagEmoji,
      coordinates: geo.coordinates,
    ));
  }

  /// Replays a synthetic +1 for every currently-active peer that has a
  /// resolved geo. Callers (e.g. the globe widget when it mounts after
  /// the user navigates into the screen) get a one-shot seed of the
  /// current world state so they don't render an empty globe despite
  /// active connections. Replayed events have isReplay=true so the UI
  /// can suppress the "new connection" burst.
  void replayCurrentPeers() {
    for (final entry in _peerArcs.entries) {
      final arc = entry.value;
      final geo = arc.geo;
      if (geo == null) continue;
      _eventController.add(UnboundedConnectionEvent(
        state: 1,
        workerIdx: arc.workerIdx,
        addr: entry.key,
        countryName: geo.countryName,
        countryCode: geo.countryCode,
        flagEmoji: geo.flagEmoji,
        coordinates: geo.coordinates,
        isReplay: true,
      ));
    }
  }

  void _stopEventSubscription() {
    // Synthesize -1 for every active peer BEFORE killing the source
    // stream. peer.Client.Stop on the Go side suppresses the box.Close
    // disconnect cascade (correct — avoids a flood of post-Stop noise),
    // so without this loop the globe would never see -1's for peers
    // that were live at toggle-time. Their arcs would orphan and rotate
    // with the globe indefinitely. With this loop, the globe sees real
    // -1's and runs them through the normal linger-then-remove path.
    for (final arc in _peerArcs.values) {
      if (arc.geo == null) continue;
      _eventController.add(UnboundedConnectionEvent(
        state: -1,
        workerIdx: arc.workerIdx,
        addr: '',
      ));
    }
    _appEventSub?.cancel();
    _appEventSub = null;
    _peerArcs.clear();
    _workerSeq = 0;
  }

  // Parses a `peer-status` FlutterEvent and folds the new phase / error
  // into ShareState. Payload is the JSON-marshalled radiance peer.Status
  // (see lantern-core/core.go EventTypePeerStatus). Phase strings come
  // from radiance/peer/peer.go's Phase constants; we map them through
  // SharePhase.fromWire so an unknown future phase falls back to idle
  // instead of crashing the consumer.
  //
  // SmC Start failures (UPnP miss, /v1/peer/register 404/4xx/5xx,
  // samizdat verify timeout, …) arrive as phase=error. Treat any such
  // failure as a signal to switch transparently to Unbounded mode —
  // the user's intent ("I want to share") is honoured via broflake
  // regardless of SmC's outcome, and raw protocol error text never
  // reaches the status card.
  void _handlePeerStatus(String message, WidgetRef widgetRef) {
    try {
      final payload = jsonDecode(message) as Map<String, dynamic>;
      final phase = SharePhase.fromWire(payload['phase'] as String?);
      final errMsg = payload['error'] as String?;
      final hasErr = errMsg != null && errMsg.isNotEmpty;

      // Terminal-phase reset in SmC mode:
      //   error → automatically fall back to Unbounded so the user
      //           keeps helping via the lower-friction path instead
      //           of seeing the screen flip off; SmC failures during
      //           Start are surfaced via this phase=error event.
      //   idle  → clean stop (user toggled off, or radiance
      //           transitioned through stopping → idle). Tear down
      //           the event subscription and return to off.
      if (phase == SharePhase.error && state.mode == ShareMode.smc) {
        appLogger.info(
          'SmC start failed, falling back to Unbounded: ${errMsg ?? ""}',
        );
        unawaited(_fallbackToUnbounded(widgetRef));
        return;
      }
      if (phase == SharePhase.idle && state.mode == ShareMode.smc) {
        _stopEventSubscription();
        // Preserve totalCount across the radiance-driven idle reset —
        // lifetime running total is persisted via appSettingProvider and
        // would otherwise be zeroed until the next app restart re-seeds
        // it from disk.
        state = ShareState(totalCount: state.totalCount);
        return;
      }
      state = state.copyWith(
        phase: phase,
        errorMessage: hasErr ? errMsg : null,
      );
    } catch (e) {
      debugPrint('share-my-connection: bad peer-status event: $e');
    }
  }

  // Seamlessly switches an in-flight SmC session to Unbounded. Called when
  // the radiance peer client reports phase=error — the SmC Start has
  // already failed and radiance has rolled the PeerShareEnabledKey
  // setting back to false, so all we owe is to flip our local state to
  // Unbounded and enable broflake.
  //
  // Constructs ShareState directly (rather than copyWith) so errorMessage
  // gets cleared — copyWith's `?? this.errorMessage` keeps the previous
  // SmC failure string around otherwise.
  //
  // Event subscription: deliberately does NOT call _startEventSubscription.
  // The error path arrives here via _handlePeerStatus which is already
  // inside the subscription started by the prior _start; flipping the
  // local state.mode keeps the same subscription forwarding events for
  // the new (Unbounded) mode. _stop is the only teardown path for the
  // subscription, and the error path doesn't go through _stop.
  Future<void> _fallbackToUnbounded(WidgetRef widgetRef) async {
    state = ShareState(
      active: true,
      probing: false,
      mode: ShareMode.unbounded,
      activeCount: 0,
      totalCount: state.totalCount,
      phase: SharePhase.idle,
    );
    final result = await widgetRef
        .read(lanternServiceProvider)
        .setUnboundedEnabled(true);
    result.fold(
      (err) {
        // Both SmC and the fallback to Unbounded failed. Roll back the
        // optimistic active=true state to off+error so the UI doesn't
        // claim Unbounded is running when nothing actually started —
        // same shape as the Unbounded branch in _start. Tear down the
        // event subscription too, since it was kept alive across the
        // SmC→Unbounded flip and there's nothing left to consume it.
        appLogger.error(
          'SmC→Unbounded fallback: setUnboundedEnabled failed: ${err.error}',
        );
        _stopEventSubscription();
        state = ShareState(
          active: false,
          probing: false,
          mode: ShareMode.off,
          activeCount: 0,
          totalCount: state.totalCount,
          phase: SharePhase.error,
          errorMessage: err.error,
        );
      },
      (_) => {},
    );
  }
}

final shareProvider =
    NotifierProvider<ShareNotifier, ShareState>(ShareNotifier.new);

/// Whether the Unbounded tab is the one on screen. Home drives this from
/// its TabController; the globe watches it to mute its tickers (via
/// TickerMode) while the user is on another tab.
///
/// Why this is needed: the globe is a software-projected sphere whose
/// rotationController calls setState() ~60fps, re-rendering the whole
/// sphere every frame. TabBarView keeps off-screen tabs mounted and does
/// not pause their tickers, so without this gate the globe keeps burning
/// a core re-projecting a sphere the user can't see while they sit on
/// the VPN tab. Defaults true so the globe runs in any context that
/// doesn't wire the signal (tests, or the single-tab layout where the
/// globe isn't built anyway).
final unboundedTabVisibleProvider =
    NotifierProvider<UnboundedTabVisible, bool>(UnboundedTabVisible.new);

class UnboundedTabVisible extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool visible) => state = visible;
}

// ─── Tab body ────────────────────────────────────────────────────────────────

/// Unbounded tab content, rendered inside the Home tab shell (see
/// home.dart). Hosts the description text, globe + arrival toast, the
/// status card with the toggle, and the advanced section. No Scaffold
/// or AppBar — the shell provides the chrome and the tab strip.
class UnboundedTab extends HookConsumerWidget {
  const UnboundedTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(shareProvider);
    final notifier = ref.read(shareProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    // First-visit welcome popup. Fires once per device (persisted via
    // appSettingProvider.unboundedWelcomeSeen) when the user first lands
    // on the Unbounded tab. Re-openable via the info-bubble icon in the
    // header.
    useEffect(() {
      final seen = ref.read(appSettingProvider).unboundedWelcomeSeen;
      if (!seen) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          showUnboundedWelcomeDialog(context, ref);
        });
      }
      return null;
    }, const []);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tappable despite reading as a static glyph: it is the only
                  // way back into the welcome dialog once it has been seen.
                  IconButton(
                    icon: const Icon(Icons.info_outline, size: 20),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'about_unbounded'.i18n,
                    onPressed: () => showUnboundedWelcomeDialog(context, ref),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'smc_intro'.i18n,
                      style: textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              flex: 3,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(child: _GlobeView()),
                  // Floating arrival toast — centered horizontally
                  // under the globe per unbounded.lantern.io
                  // (frame-020 of unbounded-russia.mp4 shows the pill
                  // sitting roughly under the globe's centre, not at
                  // a corner). The Lottie heart-spray lives INSIDE the
                  // pill via Stack(Clip.none) + negative offsets, so
                  // hearts originate from the pill's static heart and
                  // overflow upward/leftward into the globe area.
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 8,
                    child: Center(child: _ArrivalToast()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _StatusCard(state: state, onToggle: () => notifier.toggle(context, ref)),
            const SizedBox(height: 12),
            const _AutoEnableCard(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Status card ─────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final ShareState state;
  final VoidCallback onToggle;

  const _StatusCard({required this.state, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Status text source-of-truth, in priority order:
    //   1. Off and not probing → "Off"
    //   2. Probing UPnP locally → "Probing your network…"
    //   3. SmC mode → granular phase from radiance peer.Status. The
    //      backend emits one phase per stage during Start so the user
    //      sees real progress instead of "Active" for several seconds.
    //   4. Unbounded mode → static "Active — Unbounded" (no equivalent
    //      staged lifecycle on the broflake side yet).
    final modeLabel = switch ((state.mode, state.phase)) {
      // Off-with-error is a legitimate terminal state: the enable
      // path failed (e.g. setUnboundedEnabled / setPeerProxyEnabled
      // returned Left) and reverted mode to off. Render the error
      // before the catch-all "Off" so the user sees an actionable
      // message instead of a misleading off state.
      (ShareMode.off, SharePhase.error) =>
        state.errorMessage != null
            ? 'smc_status_error_with_message'.i18n.fill([state.errorMessage!])
            : 'smc_status_error_generic'.i18n,
      (ShareMode.off, _) =>
        state.probing ? 'smc_status_probing'.i18n : 'smc_status_off'.i18n,
      (ShareMode.unbounded, _) => 'smc_status_active_unbounded'.i18n,
      (ShareMode.smc, SharePhase.mappingPort) =>
        'smc_status_mapping_port'.i18n,
      (ShareMode.smc, SharePhase.detectingIp) =>
        'smc_status_detecting_ip'.i18n,
      (ShareMode.smc, SharePhase.registering) =>
        'smc_status_registering'.i18n,
      (ShareMode.smc, SharePhase.startingProxy) =>
        'smc_status_starting_proxy'.i18n,
      (ShareMode.smc, SharePhase.verifying) =>
        'smc_status_verifying'.i18n,
      (ShareMode.smc, SharePhase.serving) =>
        'smc_status_serving'.i18n,
      (ShareMode.smc, SharePhase.stopping) => 'smc_status_stopping'.i18n,
      (ShareMode.smc, SharePhase.error) =>
        state.errorMessage != null
            ? 'smc_status_error_with_message'.i18n.fill([state.errorMessage!])
            : 'smc_status_error_generic'.i18n,
      // SmC active but no phase yet (e.g. very first frame after toggle
      // before the backend's first event arrives) — fall back to the
      // legacy active label so the UI isn't blank.
      (ShareMode.smc, SharePhase.idle) => 'smc_status_active_smc'.i18n,
    };

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.public,
                    size: 20, color: Theme.of(context).hintColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: textTheme.bodyMedium,
                      children: [
                        TextSpan(text: '${'smc_status_label'.i18n}: '),
                        TextSpan(
                          text: modeLabel,
                          style: TextStyle(
                            color: state.active
                                ? AppColors.green6
                                : Theme.of(context).hintColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Match the rest of the app's toggles (vpn_setting.dart etc.).
                // SwitchButton has no built-in disabled state, so during the
                // probe we render the switch but absorb the tap so the user
                // doesn't double-fire toggle().
                SwitchButton(
                  value: state.active || state.probing,
                  onChanged: (value) {
                    if (state.probing) return;
                    onToggle();
                  },
                ),
              ],
            ),
          ),
          if (state.active) ...[
            const Divider(height: 1),
            _StatRow(
              icon: Icons.person_outline,
              label: 'smc_stat_active_now'.i18n,
              value: '${state.activeCount}',
              tooltip: 'smc_connections_tooltip'.i18n,
            ),
            const Divider(height: 1),
            _StatRow(
              icon: Icons.people_outline,
              label: 'smc_stat_total_helped'.i18n,
              value: '${state.totalCount}',
            ),
          ],
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? tooltip;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).hintColor),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: textTheme.bodyMedium)),
          if (tooltip != null) ...[
            Tooltip(
              triggerMode: TooltipTriggerMode.tap,
              waitDuration: const Duration(milliseconds: 200),
              showDuration: const Duration(seconds: 8),
              preferBelow: false,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              textStyle: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              message: tooltip!,
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: Theme.of(context).hintColor,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.blue8, // text/link
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mirrors the Unbounded Settings toggle, surfaced on the tab itself because
/// the spec puts the choice next to the thing it controls.
class _AutoEnableCard extends ConsumerWidget {
  const _AutoEnableCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final autoEnable =
        ref.watch(appSettingProvider.select((s) => s.unboundedAutoEnable));
    final notifier = ref.read(appSettingProvider.notifier);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => notifier.setUnboundedAutoEnable(!autoEnable),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.auto_mode,
                  size: 20, color: Theme.of(context).hintColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('auto_enable_unbounded'.i18n,
                        style: textTheme.bodyMedium),
                    Text('auto_enable_unbounded_subtitle'.i18n,
                        style: textTheme.labelSmall),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Checkbox(
                value: autoEnable,
                onChanged: (v) => notifier.setUnboundedAutoEnable(v ?? false),
                activeColor: AppColors.blue10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Globe ───────────────────────────────────────────────────────────────────

class _GlobeView extends ConsumerStatefulWidget {
  @override
  ConsumerState<_GlobeView> createState() => _GlobeViewState();
}

class _GlobeViewState extends ConsumerState<_GlobeView> {
  // The spec draws each arc as a cyan-to-yellow gradient, but
  // PointConnectionStyle exposes a single flat colour, so alternate the two
  // ends of that ramp by workerIdx instead. Concurrent connections stay
  // distinguishable where they overlap near the origin either way.
  static final _arcColors = [
    AppColors.blue4.withValues(alpha: 0.75),
    AppColors.yellow3.withValues(alpha: 0.75),
  ];
  static final _originPointColor = AppColors.blue4.withValues(alpha: 0.15);
  static const _peerPointColor = AppColors.green6;
  static const _atmosphereDark = AppColors.blue4;
  static const _atmosphereLight = AppColors.blue6;

  final FlutterEarthGlobeController _globeController =
      FlutterEarthGlobeController(
    // Static globe — no continuous rotation. A spinning sphere re-projects
    // in software via setState() every frame (~60fps), which is the
    // dominant CPU cost of this tab. Instead we rotate only on demand
    // (focusOnCoordinates) to bring each new connection into view, then
    // settle back to static.
    isRotating: false,
    zoom: 0,
    isZoomEnabled: false,
    showAtmosphere: true,
    atmosphereColor: _atmosphereDark,
    // Soft bloom, not a rim: a small blur reads as a hard teal ring.
    atmosphereOpacity: 0.18,
    atmosphereBlur: 22,
    // The package's defaults (ambient 0.6 / intensity 0.75) multiply the
    // surface down to ~60% on the unlit side, turning the light texture into
    // a mid-grey ball. The spec's globe renders its ocean at the texture's
    // own 233, so almost everything here is ambient; the small directional
    // term is only what keeps the sphere from reading flat.
    ambientLight: 0.97,
    lightIntensity: 0.15,
  );

  StreamSubscription<UnboundedConnectionEvent>? _eventSub;
  GlobeCoordinates? _originCoords;
  // Pending arc removals: peer goes idle → we don't yank the arc
  // immediately so brief URL-test probes (which dominate samizdat-peer
  // traffic) still register visually. Timer is cancelled if the same
  // workerIdx +1's again before it fires.
  final Map<int, Timer> _pendingRemovals = {};
  static const _arcLinger = Duration(seconds: 5);
  // workerIdx of every arc+point currently on the globe, so a stop can
  // remove them all without relying on per-peer -1 events (which _stop()
  // never emits).
  final Set<int> _drawn = {};
  Brightness? _appliedBrightness;

  @override
  void initState() {
    super.initState();
    // Subscribe FIRST so we don't miss any real-time +1 events while
    // _initOrigin is in flight. _addPeer guards on _originCoords —
    // events that arrive before origin lookup completes are still
    // tracked by the notifier's _peerArcs map (the source of truth);
    // _initOrigin's continuation calls replayCurrentPeers to draw
    // them with the now-known origin coords. Without this ordering,
    // arcs drew to GlobeCoordinates(0,0) and never got corrected.
    _eventSub = ref
        .read(shareProvider.notifier)
        .connectionEvents
        .listen(_handleEvent);
    _initOrigin();
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    for (final t in _pendingRemovals.values) {
      t.cancel();
    }
    _pendingRemovals.clear();
    _globeController.dispose();
    super.dispose();
  }

  // Theme is read here, not in initState or the controller's onLoaded:
  // reading Theme.of() outside build/didChangeDependencies registers no
  // dependency, so the first value read is latched for the widget's whole
  // life. macOS reports a platformBrightness for the first frame that can
  // still change once the platform settles — every other widget self-corrects
  // on the rebuild, but a one-shot read leaves the globe on the wrong texture
  // for the rest of the session.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    // Re-projecting a 2048x1024 texture is expensive, so ignore the inherited
    // changes that leave brightness alone.
    if (brightness == _appliedBrightness) return;
    _appliedBrightness = brightness;
    // Deferred because the controller's setters notify synchronously and
    // didChangeDependencies runs inside the build phase, so applying here
    // would mark the globe dirty while it is already building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyTheme(brightness);
    });
  }

  void _applyTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    _globeController.loadSurface(AssetImage(
      isDark
          ? 'assets/unbounded/uv-map-dark.png'
          : 'assets/unbounded/uv-map.png',
    ));
    _globeController.atmosphereColor =
        isDark ? _atmosphereDark : _atmosphereLight;
  }

  Future<void> _initOrigin() async {
    final coords = await GeoLookupService.selfLookup();
    if (!mounted) return;
    _originCoords = coords;
    _globeController.addPoint(Point(
      id: 'origin',
      coordinates: coords,
      style: PointStyle(color: _originPointColor, size: 8),
    ));
    // Center the static globe on the user's own location so the first
    // thing shown is "us" (instant — no intro spin).
    _globeController.focusOnCoordinates(coords, animate: false);
    // Origin coords are now known — draw any peers that connected
    // before (or during) the origin lookup. _addPeer's null-guard
    // skipped them earlier; replayCurrentPeers re-fires +1 events
    // for everything in _peerArcs.
    ref.read(shareProvider.notifier).replayCurrentPeers();
  }

  void _handleEvent(UnboundedConnectionEvent event) {
    if (event.state == 1 && event.coordinates != null) {
      // Cancel any lingering removal — same workerIdx is back.
      _pendingRemovals.remove(event.workerIdx)?.cancel();
      _addPeer(event);
    } else if (event.state == -1) {
      // Linger the arc so brief connections still register visually.
      _pendingRemovals[event.workerIdx]?.cancel();
      _pendingRemovals[event.workerIdx] = Timer(_arcLinger, () {
        _pendingRemovals.remove(event.workerIdx);
        if (!mounted) return;
        _removePeer(event.workerIdx);
      });
    }
  }

  // Jitter coords by a workerIdx-derived offset so multiple peers from
  // the same country don't draw arcs on top of each other. Hash-based so
  // the same widx always lands in the same slot — no jitter drift on
  // replay.
  GlobeCoordinates _jittered(GlobeCoordinates base, int widx) {
    final hash = widx * 2654435761; // Knuth multiplicative hash
    final dLat = ((hash >> 4) & 0xff) / 255.0 * 4.0 - 2.0; // [-2, +2]°
    final dLng = ((hash >> 12) & 0xff) / 255.0 * 4.0 - 2.0;
    return GlobeCoordinates(base.latitude + dLat, base.longitude + dLng);
  }

  void _addPeer(UnboundedConnectionEvent event) {
    if (!mounted) return;
    // Origin not yet resolved — skip the draw rather than render an
    // arc to GlobeCoordinates(0, 0). The peer is still tracked in
    // the notifier's _peerArcs map, and _initOrigin's continuation
    // calls replayCurrentPeers once origin is known so anything
    // skipped here gets drawn with the correct destination.
    if (_originCoords == null) return;
    final coords = _jittered(event.coordinates!, event.workerIdx);
    // Solid arc, censored user → uncensored peer (us), drawn in once on
    // add (animateOnAdd). dashAnimateTime is 0 on purpose: a non-zero
    // value makes flutter_earth_globe run its ~60fps repaint loop for as
    // long as any arc exists, which would re-spike the CPU the whole time
    // a peer is connected — the same per-frame full-sphere repaint we
    // removed by disabling rotation.
    _globeController.addPointConnection(PointConnection(
      id: 'conn_${event.workerIdx}',
      start: coords,
      end: _originCoords!,
      curveScale: .6,
      style: PointConnectionStyle(
        color: _arcColors[event.workerIdx.abs() % _arcColors.length],
        lineWidth: 3,
        type: PointConnectionType.solid,
        dashAnimateTime: 0,
        animateOnAdd: true,
      ),
    ));
    _globeController.addPoint(Point(
      id: 'peer_${event.workerIdx}',
      coordinates: coords,
      style: PointStyle(color: _peerPointColor, size: 6),
    ));
    _drawn.add(event.workerIdx);
    // Turn the static globe to bring the new connection into view — a
    // brief, finite animation that settles back to static (no continuous
    // cost). Without it, an arc on the far hemisphere of a non-spinning
    // globe would be invisible.
    _globeController.focusOnCoordinates(
      coords,
      animate: true,
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOutCubic,
    );
  }

  void _removePeer(int workerIdx) {
    _globeController.removePointConnection('conn_$workerIdx');
    _globeController.removePoint('peer_$workerIdx');
    _drawn.remove(workerIdx);
  }

  // Drop every arc + peer point at once. Used on the active->off edge,
  // since _stop() tears down the event stream without emitting the -1s
  // that would otherwise remove each arc.
  void _clearAllPeers() {
    for (final t in _pendingRemovals.values) {
      t.cancel();
    }
    _pendingRemovals.clear();
    for (final workerIdx in _drawn.toList()) {
      _globeController.removePointConnection('conn_$workerIdx');
      _globeController.removePoint('peer_$workerIdx');
    }
    _drawn.clear();
  }

  @override
  Widget build(BuildContext context) {
    // Pause the globe's tickers while the Unbounded tab is off screen.
    // rotating_globe builds its AnimationControllers with `vsync: this`,
    // so an ancestor TickerMode(enabled: false) freezes any in-flight
    // focusOnCoordinates turn and the package's idle repaint loop at once
    // — no point spending frames on a globe the user can't see.
    final visible = ref.watch(unboundedTabVisibleProvider);
    // _stop() tears down the upstream event subscription without emitting
    // -1 events, so without this the globe keeps animating whatever arcs
    // were live at toggle-off. Clear them on the active->off edge.
    ref.listen(shareProvider.select((s) => s.active), (prev, next) {
      if (prev == true && next == false) _clearAllPeers();
    });
    return TickerMode(
      enabled: visible,
      child: LayoutBuilder(
      builder: (context, constraints) {
        // FlutterEarthGlobe positions the sphere relative to MediaQuery.size
        // (i.e. the full screen). Without overriding it the globe ends up
        // off-screen when it lives in a non-fullscreen layout slot. The
        // MediaQuery override + Positioned.fill keeps the sphere centred
        // within this widget's box; ClipRect keeps arcs from painting
        // outside the box when they curve high.
        final widgetSize = Size(constraints.maxWidth, constraints.maxHeight);
        // Driven off width, since the spec sizes the globe as a fraction of
        // the frame (~50% of it across), then clamped so a short slot doesn't
        // push the sphere out of its box.
        final radius = min(
          constraints.maxWidth * 0.275,
          constraints.maxHeight * 0.42,
        );
        return ClipRect(
          // copyWith preserves the inherited devicePixelRatio,
          // textScaleFactor, padding/insets etc. — constructing
          // MediaQueryData from scratch with just `size:` would drop
          // those, breaking high-DPI rendering (pixel ratio falls to
          // 1.0) and accessibility scaling for the globe subtree.
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(size: widgetSize),
            child: Stack(
              children: [
                // Sits behind the sphere because the package paints no
                // shadow of its own; matched to the spec's Globe effect.
                Align(
                  alignment: const Alignment(0.0, -0.1),
                  child: Container(
                    width: radius * 2,
                    height: radius * 2,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x42006163),
                          offset: Offset(0, 4),
                          blurRadius: 64,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned.fill(
                  child: FlutterEarthGlobe(
                    controller: _globeController,
                    radius: radius,
                    alignment: const Alignment(0.0, -0.1),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      ),
    );
  }
}

// ─── Arrival toast ───────────────────────────────────────────────────────────

/// Floating notification overlay shown under the globe. Mirrors the
/// unbounded.lantern.io notification pattern: heart-burst on the left,
/// `Helping a new person in <country>` text on the right while a peer
/// is connecting. When no peer has arrived recently, falls back to
/// `Waiting for connections...` (no heart) per the Figma spec. Slides
/// up + fades in, auto-hides connection arrivals after ~3.5s.
class _ArrivalToast extends ConsumerStatefulWidget {
  const _ArrivalToast();

  @override
  ConsumerState<_ArrivalToast> createState() => _ArrivalToastState();
}

class _ArrivalToastState extends ConsumerState<_ArrivalToast> {
  StreamSubscription<UnboundedConnectionEvent>? _sub;
  Timer? _hideTimer;
  UnboundedConnectionEvent? _current;

  @override
  void initState() {
    super.initState();
    _sub = ref
        .read(shareProvider.notifier)
        .connectionEvents
        .listen(_onEvent);
  }

  void _onEvent(UnboundedConnectionEvent event) {
    if (event.state != 1 || event.isReplay) return;
    if (event.countryName.isEmpty) return;
    if (!mounted) return;
    _hideTimer?.cancel();
    setState(() => _current = event);
    _hideTimer = Timer(const Duration(milliseconds: 3500), () {
      if (!mounted) return;
      setState(() => _current = null);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final event = _current;
    // _current only tracks arrivals from the last few seconds, so its absence
    // does not mean nobody is connected. The idle pill has to key off the live
    // peer count or it claims we are waiting for connections directly above a
    // stat reporting several active ones.
    final hasPeers = ref.watch(shareProvider).activeCount > 0;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
                  begin: const Offset(0, 0.4), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        ),
      ),
      child: event == null
          ? (hasPeers
              ? const SizedBox.shrink(key: ValueKey('arrival-idle'))
              : const _WaitingCard(key: ValueKey('arrival-waiting')))
          : _ArrivalCard(
              // ValueKey forces AnimatedSwitcher to swap children when a
              // new arrival lands while the previous toast is still up,
              // so the Lottie restarts cleanly.
              key: ValueKey('arrival-${event.workerIdx}'),
              countryName: event.countryName,
              flagEmoji: event.flagEmoji,
            ),
    );
  }
}

class _ArrivalCard extends StatelessWidget {
  const _ArrivalCard({
    super.key,
    required this.countryName,
    required this.flagEmoji,
  });

  final String countryName;
  final String flagEmoji;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
        // clipBehavior:none lets the absolutely-positioned Lottie burst
        // (inside the heart slot below) overflow the pill's rounded
        // bounds and spray upward across the globe.
        clipBehavior: Clip.none,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: Colors.black12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Heart slot with the static heart icon + a Lottie burst
            // that overflows upward and rightward into the globe area.
            // Layout mirrors unbounded's CSS one-for-one: heart in a
            // 22×19 slot, Lottie absolute-positioned at bottom:-55,
            // left:-105, width:420 (scaled to the slot's natural
            // bottom/left = pill heart's bottom/left).
            SizedBox(
              width: 22,
              height: 19,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: const [
                  // Lottie spreads upward + rightward from the heart.
                  // The size matches explosion.json's native 420×502
                  // canvas — unbounded.lantern.io's CSS uses width:420
                  // with height:auto for the same effect. Forcing the
                  // height to 420 (as we did before) scaled the
                  // animation down by ~83% via BoxFit.contain and lost
                  // ~82px of upward spread, leaving the hearts visibly
                  // smaller and clustered just above the pill instead
                  // of fanning out across the globe.
                  Positioned(
                    bottom: -55,
                    left: -105,
                    width: 420,
                    height: 502,
                    child: _ArrivalLottie(),
                  ),
                  CustomPaint(painter: _HeartPainter()),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // unbounded.lantern.io renders just `heart + text`, no flag
            // emoji — matching that exactly so the pill width stays in
            // bounds and the layout reads cleanly. flagEmoji is still
            // carried on the event for future use (e.g. label above
            // the peer's arc on the globe).
            Text(
              'smc_arrival_toast'.i18n.fill([countryName]),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Plays explosion.json once per build. Stateful so each _ArrivalCard
/// instance (keyed on workerIdx) gets its own clean Lottie playback.
class _ArrivalLottie extends StatefulWidget {
  const _ArrivalLottie();

  @override
  State<_ArrivalLottie> createState() => _ArrivalLottieState();
}

class _ArrivalLottieState extends State<_ArrivalLottie>
    with TickerProviderStateMixin {
  AnimationController? _ctrl;

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      'assets/unbounded/explosion.json',
      repeat: false,
      fit: BoxFit.contain,
      onLoaded: (composition) {
        // Lottie can fire onLoaded after dispose if the surrounding
        // _ArrivalCard rebuilds rapidly (worker swap mid-load). Guard
        // mounted and discard any controller that was already attached
        // so we don't leak a ticker on rebuild.
        if (!mounted) return;
        _ctrl?.dispose();
        _ctrl = AnimationController(
          vsync: this,
          duration: composition.duration,
        )..forward();
        setState(() {});
      },
      controller: _ctrl,
    );
  }
}

/// Idle-state companion to _ArrivalCard. Same pill chrome, no heart,
/// `Waiting for connections...` text. Shown whenever the toast switch
/// has no current arrival to display.
class _WaitingCard extends StatelessWidget {
  const _WaitingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: Colors.black12),
        ),
        child: Text(
          'unbounded_waiting_for_connections'.i18n,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).hintColor,
          ),
        ),
      ),
    );
  }
}

/// Pink heart from `getlantern/unbounded` — exact SVG path coords
/// (viewBox 0 0 32 27, fill #FF5A79).
class _HeartPainter extends CustomPainter {
  const _HeartPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFFF5A79);
    final path = Path()
      ..moveTo(31.5035, 5.87209)
      ..cubicTo(28.0938, -3.18494, 17.0123, 0.864084, 16, 5.3926)
      ..cubicTo(14.6148, 0.597701, 3.79965, -2.97183, 0.496497, 5.87209)
      ..cubicTo(-3.17959, 15.7283, 14.7214, 24.5722, 16, 26.0107)
      ..cubicTo(17.2786, 24.8386, 35.1796, 15.5684, 31.5035, 5.87209)
      ..close();
    // Scale path from native 32x27 to the canvas size.
    final scaled = path.transform(Matrix4.diagonal3Values(
      size.width / 32.0,
      size.height / 27.0,
      1.0,
    ).storage);
    canvas.drawPath(scaled, paint);
  }

  @override
  bool shouldRepaint(_HeartPainter oldDelegate) => false;
}

// ─── Advanced section ────────────────────────────────────────────────────────

/// UnboundedAdvancedCard exposes power-user knobs that don't belong on the
/// Unbounded tab itself. Today: manual port forward (for users on networks
/// where UPnP doesn't work, who've configured a router-side port forward by
/// hand). Lives in Unbounded Settings.
///
/// Persisted via the existing FFI setPeerManualPort path; takes effect
/// on the next peer.Client.Start (i.e. next time the toggle is flipped
/// on after editing the field).
class UnboundedAdvancedCard extends HookConsumerWidget {
  const UnboundedAdvancedCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Theme(
        // Strip the divider lines ExpansionTile draws by default — the
        // container border already gives the section its own outline.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text('smc_advanced'.i18n, style: textTheme.labelLarge),
          subtitle: Text(
            'smc_advanced_subtitle'.i18n,
            style: textTheme.labelSmall,
          ),
          children: const [_ManualPortField()],
        ),
      ),
    );
  }
}

class _ManualPortField extends HookConsumerWidget {
  const _ManualPortField();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final controller = useTextEditingController();
    final loaded = useState(false);
    final saving = useState(false);
    final lastSaved = useState<int?>(null);

    // Load the persisted port once. We deliberately don't watch a
    // provider here — the value rarely changes and a one-shot read
    // matches the rest of the radianceSettingsProvider's eager-load
    // pattern.
    //
    // Dispose guard: the user can navigate away while the
    // getPeerManualPort future is still in flight (especially on the
    // FFI path where it can take several ms). Without the guard, the
    // continuation would write to a disposed TextEditingController
    // and useState ValueNotifiers and throw. `disposed` flips on the
    // useEffect cleanup so post-dispose writes short-circuit.
    useEffect(() {
      var disposed = false;
      Future.microtask(() async {
        final result =
            await ref.read(lanternServiceProvider).getPeerManualPort();
        if (disposed) return;
        result.fold((_) => null, (port) {
          if (port > 0) controller.text = port.toString();
          lastSaved.value = port;
        });
        loaded.value = true;
      });
      return () => disposed = true;
    }, const []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'smc_manual_port'.i18n,
          style: textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'smc_manual_port_description'.i18n,
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: false,
                  signed: false,
                ),
                decoration: InputDecoration(
                  labelText: 'smc_manual_port_label'.i18n,
                  hintText: 'smc_manual_port_hint'.i18n,
                  border: const OutlineInputBorder(),
                  isDense: true,
                  enabled: loaded.value && !saving.value,
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: (loaded.value && !saving.value)
                  ? () => _save(ref, context, controller, saving, lastSaved)
                  : null,
              child: saving.value
                  ? const SizedBox(
                      height: 16, width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('smc_manual_port_save'.i18n),
            ),
          ],
        ),
        if (lastSaved.value != null && lastSaved.value! > 0) ...[
          const SizedBox(height: 8),
          Text(
            'smc_manual_port_currently_set'.i18n.fill([lastSaved.value!]),
            style: textTheme.bodySmall?.copyWith(
              color: Theme.of(context).hintColor,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _save(
    WidgetRef ref,
    BuildContext context,
    TextEditingController controller,
    ValueNotifier<bool> saving,
    ValueNotifier<int?> lastSaved,
  ) async {
    saving.value = true;
    try {
      final raw = controller.text.trim();
      int port = 0;
      if (raw.isNotEmpty) {
        port = int.tryParse(raw) ?? -1;
        if (port < 1 || port > 65535) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('smc_manual_port_out_of_range'.i18n)),
            );
          }
          return;
        }
      }
      final result =
          await ref.read(lanternServiceProvider).setPeerManualPort(port);
      result.fold(
        (err) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(err.localizedErrorMessage)),
            );
          }
        },
        (_) {
          lastSaved.value = port;
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(port == 0
                    ? 'smc_manual_port_cleared'.i18n
                    : 'smc_manual_port_saved'.i18n.fill([port])),
              ),
            );
          }
        },
      );
    } finally {
      saving.value = false;
    }
  }
}

// ─── Disclosure dialog ───────────────────────────────────────────────────────

/// One disclosure for both sharing modes. The user is not asked to pick a
/// mode — that follows from whether their router supports port forwarding —
/// so the copy describes the worse case (their own IP as the exit) and the
/// relayed case, and the single choice is whether to share at all.
class ShareConsentDialog extends StatelessWidget {
  const ShareConsentDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AlertDialog(
      title: Text('share_consent_title'.i18n),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('share_consent_body_what'.i18n, style: textTheme.bodyMedium),
            const SizedBox(height: 12),
            Text('share_consent_body_ip'.i18n, style: textTheme.bodyMedium),
            const SizedBox(height: 12),
            Text(
              'share_consent_body_safety'.i18n,
              style: textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).hintColor,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('share_consent_decline'.i18n),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('share_consent_accept'.i18n),
        ),
      ],
    );
  }
}

// ─── Welcome dialog ──────────────────────────────────────────────────────────

/// Shows the first-visit Unbounded welcome popup per Figma
/// (figma.com/design/hNlyYToB5TnX9SDBFDYJTq?node-id=2403-19287).
/// Idempotent: dismissing the dialog (either button OR scrim tap)
/// flips appSettingProvider.unboundedWelcomeSeen → true so the dialog
/// only fires on the first visit. The info-bubble icon in the
/// Unbounded tab header calls this same function to re-open it later.
void showUnboundedWelcomeDialog(BuildContext context, WidgetRef ref) {
  // Capture the notifier up front: whenComplete fires after the dialog
  // closes, by which point the calling widget (and its WidgetRef) may be
  // disposed if navigation replaced Home — ref.read would then throw. The
  // notifier is owned by the root container and outlives the widget.
  final appSetting = ref.read(appSettingProvider.notifier);
  showDialog<void>(
    context: context,
    builder: (_) => const _UnboundedWelcomeDialog(),
  ).whenComplete(() {
    appSetting.setUnboundedWelcomeSeen(true);
  });
}

class _UnboundedWelcomeDialog extends StatelessWidget {
  const _UnboundedWelcomeDialog();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Heart logo, matching the Figma's heart-Lantern motif.
              const Center(
                child: SizedBox(
                  width: 40,
                  height: 34,
                  child: CustomPaint(painter: _HeartPainter()),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'unbounded_welcome_title'.i18n,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'unbounded_welcome_body_1'.i18n,
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'unbounded_welcome_body_2'.i18n,
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'unbounded_welcome_body_3'.i18n,
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              // No "Learn more" button until the explainer URL is wired
              // (will be re-added pointing at AppUrls.unbounded). Showing
              // a button with an empty onPressed in production reads as a
              // dead control.
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('got_it'.i18n),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
