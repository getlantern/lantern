// Share My Connection — unified screen for both Unbounded and the
// samizdat-over-UPnP "Share My Connection" modes:
//   - Toggle ON triggers a (mocked) UPnP probe.
//   - If UPnP works AND the user accepts the SmC disclosure, run SmC mode
//     (calls into radiance via the existing radianceSettingsProvider
//     setPeerProxy path).
//   - Otherwise fall back to Unbounded mode (UI-only for now; broflake
//     wire-up follows once radiance#336 lands).
//   - Globe animates connection arcs from peer-connection FlutterEvents
//     streamed up from radiance.
//
// UPnP probe is still mocked (a coin-flip) until the FFI binding lands;
// SmC mode is real — flipping the toggle starts the radiance peer
// module on this branch.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

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
    String? errorMessage,
  }) =>
      ShareState(
        active: active ?? this.active,
        probing: probing ?? this.probing,
        mode: mode ?? this.mode,
        activeCount: activeCount ?? this.activeCount,
        totalCount: totalCount ?? this.totalCount,
        phase: phase ?? this.phase,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

// ─── Notifier (mock-backed) ──────────────────────────────────────────────────

class _PeerArc {
  _PeerArc(this.workerIdx) : streamCount = 1;
  final int workerIdx;
  int streamCount;
  // Geo is resolved async after the first +1 lands. Until then the peer is
  // tracked but no arc is emitted — avoids a flash of "unknown" arcs.
  PeerGeo? geo;
}

class ShareNotifier extends Notifier<ShareState> {
  // Persisted in real impl; in-process for the prototype so the disclosure
  // re-fires on app restart and is easy to demo.
  bool _smcAck = false;

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
    ref.onDispose(() {
      _stopEventSubscription();
      _eventController.close();
    });
    return const ShareState();
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

    state = state.copyWith(probing: true);

    // Manual port forward bypasses both the UPnP probe and the SmC
    // disclosure dialog. Configuring a port in Advanced is an explicit
    // user-driven SmC opt-in — they wouldn't have set it up if they
    // weren't sure they wanted to share via the residential-IP path.
    final manualPortRes =
        await widgetRef.read(lanternServiceProvider).getPeerManualPort();
    final manualPort = manualPortRes.fold((_) => 0, (p) => p);
    if (manualPort > 0) {
      await _start(widgetRef, ShareMode.smc);
      return;
    }

    // MOCK: real UPnP probe via FFI is not yet wired; coin-flip the
    // result so the demo exercises both paths across runs without a
    // manual port set.
    await Future.delayed(const Duration(milliseconds: 1500));
    final upnpAvailable = Random().nextBool();
    if (!upnpAvailable) {
      await _start(widgetRef, ShareMode.unbounded);
      return;
    }

    if (_smcAck) {
      await _start(widgetRef, ShareMode.smc);
      return;
    }

    if (!context.mounted) {
      state = state.copyWith(probing: false);
      return;
    }

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const SmcDisclosureDialog(),
    );

    if (accepted == null) {
      // User dismissed without choosing — leave off.
      state = state.copyWith(probing: false);
      return;
    }
    if (accepted) {
      _smcAck = true;
      await _start(widgetRef, ShareMode.smc);
    } else {
      await _start(widgetRef, ShareMode.unbounded);
    }
  }

  /// Programmatic entry point used by the Home shell's auto-enable
  /// listener (VPN-connected → Unbounded on). Mirrors `toggle()` but
  /// skips the disclosure dialog because the user has already opted
  /// in via the Unbounded Settings sheet. No-ops if already active or
  /// in flight.
  Future<void> autoStart(WidgetRef widgetRef) async {
    if (state.active || state.probing) return;
    state = state.copyWith(probing: true);
    final manualPortRes =
        await widgetRef.read(lanternServiceProvider).getPeerManualPort();
    final manualPort = manualPortRes.fold((_) => 0, (p) => p);
    if (manualPort > 0) {
      await _start(widgetRef, ShareMode.smc);
      return;
    }
    // MOCK UPnP probe — same as toggle(), pending real FFI.
    await Future.delayed(const Duration(milliseconds: 1500));
    final upnpAvailable = Random().nextBool();
    await _start(
      widgetRef,
      upnpAvailable ? ShareMode.smc : ShareMode.unbounded,
    );
  }

  Future<void> _start(WidgetRef widgetRef, ShareMode mode) async {
    state = ShareState(
      active: true,
      probing: false,
      mode: mode,
      activeCount: 0,
      totalCount: 0,
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
        await widgetRef
            .read(radianceSettingsProvider.notifier)
            .setPeerProxy(true);
        break;
      case ShareMode.unbounded:
        // Unbounded is the broflake / WebRTC widget-proxy mode. Local
        // opt-in only — actual run state also depends on the server's
        // Features[unbounded] flag and supplied UnboundedConfig (see
        // radiance/unbounded/unbounded.go shouldRunUnbounded). When
        // running, broflake's OnConnectionChange callback emits
        // unbounded.ConnectionEvent → forwarded by lantern-core as the
        // same EventTypePeerConnection FlutterEvent the SmC path uses,
        // so this Dart subscription consumes both protocols uniformly.
        await widgetRef
            .read(lanternServiceProvider)
            .setUnboundedEnabled(true);
        break;
      case ShareMode.off:
        break;
    }
  }

  Future<void> _stop(WidgetRef widgetRef) async {
    _stopEventSubscription();
    final priorMode = state.mode;
    state = const ShareState();
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
        _handlePeerStatus(event.message);
        return;
      }
      if (event.eventType != 'peer-connection') return;
      try {
        final payload = jsonDecode(event.message) as Map<String, dynamic>;
        final eventState = (payload['state'] as num?)?.toInt() ?? 0;
        final source = (payload['source'] as String?) ?? '';
        // Globe only cares about the IP — strip ":port".
        final ip = source.split(':').first;
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
          state = state.copyWith(
            activeCount: state.activeCount + 1,
            totalCount: state.totalCount + 1,
          );
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
        // Malformed event — log via dev print to avoid bringing in the
        // appLogger here. Real impl can switch to slog.
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
  void _handlePeerStatus(String message) {
    try {
      final payload = jsonDecode(message) as Map<String, dynamic>;
      final phase = SharePhase.fromWire(payload['phase'] as String?);
      final errMsg = payload['error'] as String?;
      state = state.copyWith(
        phase: phase,
        errorMessage: (errMsg == null || errMsg.isEmpty) ? null : errMsg,
      );
    } catch (e) {
      debugPrint('share-my-connection: bad peer-status event: $e');
    }
  }
}

final shareProvider =
    NotifierProvider<ShareNotifier, ShareState>(ShareNotifier.new);

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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'Help others bypass censorship by securely sharing your '
                    'connection.',
                    style: textTheme.bodyMedium,
                  ),
                ),
                // Info bubble — re-opens the welcome popup. Mirrors the
                // Figma spec, which calls out the info-bubble as the
                // way back into the explanatory dialog.
                IconButton(
                  icon: const Icon(Icons.info_outline, size: 20),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'About Unbounded',
                  onPressed: () => showUnboundedWelcomeDialog(context, ref),
                ),
              ],
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
            const _AdvancedCard(),
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
      (ShareMode.off, _) =>
        state.probing ? 'Probing your network…' : 'Off',
      (ShareMode.unbounded, _) =>
        'Active — sharing via Unbounded (WebRTC)',
      (ShareMode.smc, SharePhase.mappingPort) =>
        'Opening port on your router…',
      (ShareMode.smc, SharePhase.detectingIp) =>
        'Detecting your public IP…',
      (ShareMode.smc, SharePhase.registering) =>
        'Registering with Lantern…',
      (ShareMode.smc, SharePhase.startingProxy) =>
        'Starting local proxy…',
      (ShareMode.smc, SharePhase.verifying) =>
        'Verifying connectivity…',
      (ShareMode.smc, SharePhase.serving) =>
        'Sharing — ready to serve users in censored regions',
      (ShareMode.smc, SharePhase.stopping) => 'Stopping…',
      (ShareMode.smc, SharePhase.error) =>
        state.errorMessage != null
            ? "Couldn't share: ${state.errorMessage}"
            : "Couldn't share — try toggling again",
      // SmC active but no phase yet (e.g. very first frame after toggle
      // before the backend's first event arrives) — fall back to the
      // legacy active label so the UI isn't blank.
      (ShareMode.smc, SharePhase.idle) =>
        'Active — sharing via Share My Connection (residential proxy)',
    };

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      modeLabel,
                      style: textTheme.bodyMedium?.copyWith(
                        color: state.active
                            ? AppColors.blue4
                            : Theme.of(context).hintColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
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
          if (state.active) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Stack(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _Stat(label: 'Active now', value: '${state.activeCount}'),
                    _Stat(label: 'Total today', value: '${state.totalCount}'),
                  ],
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Tooltip(
                    triggerMode: TooltipTriggerMode.tap,
                    waitDuration: const Duration(milliseconds: 200),
                    showDuration: const Duration(seconds: 8),
                    preferBelow: false,
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    textStyle: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    message:
                        'Most connections are short liveness probes — Lantern '
                        'clients periodically check that this peer is reachable '
                        'before sending real traffic. A quick burst from many '
                        'locations is normal; an arc that lingers represents an '
                        'actual user session.',
                    child: Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(value, style: textTheme.headlineSmall),
        Text(label, style: textTheme.labelSmall),
      ],
    );
  }
}

// ─── Globe ───────────────────────────────────────────────────────────────────

class _GlobeView extends ConsumerStatefulWidget {
  @override
  ConsumerState<_GlobeView> createState() => _GlobeViewState();
}

class _GlobeViewState extends ConsumerState<_GlobeView> {
  static final _arcColor = AppColors.blue4.withValues(alpha: 0.75);
  static final _originPointColor = AppColors.blue4.withValues(alpha: 0.15);
  static final _peerPointColor = AppColors.yellow3.withValues(alpha: 0.15);
  static const _atmosphereDark = AppColors.blue4;
  static const _atmosphereLight = AppColors.blue6;

  final FlutterEarthGlobeController _globeController =
      FlutterEarthGlobeController(
    isRotating: true,
    rotationSpeed: 0.04,
    zoom: 0,
    isZoomEnabled: false,
    showAtmosphere: true,
    atmosphereColor: _atmosphereDark,
    atmosphereOpacity: 0.2,
    atmosphereBlur: 20,
  );

  StreamSubscription<UnboundedConnectionEvent>? _eventSub;
  GlobeCoordinates? _originCoords;
  // Pending arc removals: peer goes idle → we don't yank the arc
  // immediately so brief URL-test probes (which dominate samizdat-peer
  // traffic) still register visually. Timer is cancelled if the same
  // workerIdx +1's again before it fires.
  final Map<int, Timer> _pendingRemovals = {};
  static const _arcLinger = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _globeController.onLoaded = () {
      if (!mounted) return;
      _applyTheme();
    };
    _initOrigin();
    // Subscribe BEFORE the replay call so we don't miss any concurrent
    // +1 events. The broadcast stream delivers synchronously when added,
    // but the replay events come from inside the same notifier so order
    // is preserved.
    _eventSub = ref
        .read(shareProvider.notifier)
        .connectionEvents
        .listen(_handleEvent);
    ref.read(shareProvider.notifier).replayCurrentPeers();
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

  void _applyTheme() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
    final coords = _jittered(event.coordinates!, event.workerIdx);
    // Arc direction is censored user → uncensored peer (us). The dash
    // animation flows from start to end, so the visual "travel" reads
    // as traffic arriving at our peer to escape censorship.
    _globeController.addPointConnection(PointConnection(
      id: 'conn_${event.workerIdx}',
      start: coords,
      end: _originCoords ?? const GlobeCoordinates(0, 0),
      curveScale: .6,
      style: PointConnectionStyle(
        color: _arcColor,
        lineWidth: 3,
        type: PointConnectionType.solid,
        dashAnimateTime: 1000,
        dashSize: 13,
        spacing: 15,
        dotSize: 10,
        animateOnAdd: true,
      ),
    ));
    _globeController.addPoint(Point(
      id: 'peer_${event.workerIdx}',
      coordinates: coords,
      style: PointStyle(color: _peerPointColor, size: 6),
    ));
  }

  void _removePeer(int workerIdx) {
    _globeController.removePointConnection('conn_$workerIdx');
    _globeController.removePoint('peer_$workerIdx');
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // FlutterEarthGlobe positions the sphere relative to MediaQuery.size
        // (i.e. the full screen). Without overriding it the globe ends up
        // off-screen when it lives in a non-fullscreen layout slot. The
        // MediaQuery override + Positioned.fill keeps the sphere centred
        // within this widget's box; ClipRect keeps arcs from painting
        // outside the box when they curve high.
        final widgetSize = Size(constraints.maxWidth, constraints.maxHeight);
        final radius =
            min(constraints.maxWidth, constraints.maxHeight) / 2 * 0.7;
        return ClipRect(
          child: MediaQuery(
            data: MediaQueryData(size: widgetSize),
            child: Stack(
              children: [
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
          // Idle state — the spec wants a "Waiting for connections..."
          // pill rather than empty space, so the user knows the screen
          // is live and just nothing has arrived yet.
          ? const _WaitingCard(key: ValueKey('arrival-waiting'))
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
                  // height is auto from BoxFit.contain on its 420-wide
                  // canvas; explosion.json is roughly square so ~420
                  // tall, but most of that is above the heart due to
                  // the negative bottom offset.
                  Positioned(
                    bottom: -55,
                    left: -105,
                    width: 420,
                    height: 420,
                    child: _ArrivalLottie(),
                  ),
                  CustomPaint(painter: _HeartPainter()),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // unbounded.lantern.io renders just `heart + text`, no flag
            // emoji — matching that exactly so the pill width stays in
            // bounds and the layout reads cleanly. flagEmoji is still
            // carried on the event for future use (e.g. label above
            // the peer's arc on the globe).
            Text(
              'Helping a new person in $countryName',
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
          'Waiting for connections...',
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

// ─── Lottie burst layer ──────────────────────────────────────────────────────

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

/// _AdvancedCard exposes power-user knobs that don't belong in the
/// always-visible status card. Today: manual port forward (for users on
/// networks where UPnP doesn't work, who've configured a router-side
/// port forward by hand).
///
/// Persisted via the existing FFI setPeerManualPort path; takes effect
/// on the next peer.Client.Start (i.e. next time the toggle is flipped
/// on after editing the field).
class _AdvancedCard extends HookConsumerWidget {
  const _AdvancedCard();

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
          title: Text('Advanced', style: textTheme.labelLarge),
          subtitle: Text(
            'For users whose router doesn\'t support UPnP',
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
    useEffect(() {
      Future.microtask(() async {
        final result =
            await ref.read(lanternServiceProvider).getPeerManualPort();
        result.fold((_) => null, (port) {
          if (port > 0) controller.text = port.toString();
          lastSaved.value = port;
        });
        loaded.value = true;
      });
      return null;
    }, const []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Manual port forward',
          style: textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'If your router doesn\'t support UPnP, configure a port forward '
          'on your router and enter the port number here. Lantern will use '
          'it as the external port instead of probing UPnP. Leave blank to '
          'use UPnP (default).',
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
                  labelText: 'Port',
                  hintText: 'e.g. 5698',
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
                  : const Text('Save'),
            ),
          ],
        ),
        if (lastSaved.value != null && lastSaved.value! > 0) ...[
          const SizedBox(height: 8),
          Text(
            'Currently set to port ${lastSaved.value}. Toggle Share My '
            'Connection off and back on for the change to take effect.',
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
              const SnackBar(content: Text('Port must be between 1 and 65535')),
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
                    ? 'Manual port cleared — using UPnP'
                    : 'Manual port set to $port'),
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

class SmcDisclosureDialog extends StatelessWidget {
  const SmcDisclosureDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('Use full Share My Connection?'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your network supports the higher-bandwidth, more '
              'block-resistant mode. In this mode, your home internet '
              'connection routes traffic for users in censored countries.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Lantern blocks abuse destinations, rotates credentials, '
              'and operates as a "mere conduit" under DMCA § 512(a) — '
              'but your IP address will appear in the destination\'s '
              'logs while you\'re sharing.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'You can still help by selecting "Basic mode" instead, '
              'which uses ephemeral WebRTC connections that are not '
              'tied to your IP in the same way.',
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
          child: const Text('Basic mode (Unbounded)'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Full mode (SmC)'),
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
  showDialog<void>(
    context: context,
    builder: (_) => const _UnboundedWelcomeDialog(),
  ).whenComplete(() {
    ref.read(appSettingProvider.notifier).setUnboundedWelcomeSeen(true);
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
                  'Welcome to Unbounded',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "When you enable Unbounded, your device becomes part of a "
                "network of 'digital bridges' to the open internet. "
                "Censored users connect to these bridges, allowing them "
                "to bypass government-imposed restrictors and access the "
                "information they need.",
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'This collective effort makes censorship harder to '
                'enforce, expanding access to the open internet.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'You can remove Unbounded from the interface anytime in '
                'Settings.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      // TODO: deep-link to the Unbounded explainer page
                      // once the URL is wired (AppUrls.unbounded?).
                    },
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: const Text('Learn more'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Got it'),
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
