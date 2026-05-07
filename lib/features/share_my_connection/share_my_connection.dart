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
import 'package:flutter_earth_globe/flutter_earth_globe.dart';
import 'package:flutter_earth_globe/flutter_earth_globe_controller.dart';
import 'package:flutter_earth_globe/globe_coordinates.dart';
import 'package:flutter_earth_globe/point.dart';
import 'package:flutter_earth_globe/point_connection.dart';
import 'package:flutter_earth_globe/point_connection_style.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/unbounded_connection_event.dart';
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

class ShareState {
  final bool active;
  final bool probing;
  final ShareMode mode;
  final int activeCount;
  final int totalCount;

  const ShareState({
    this.active = false,
    this.probing = false,
    this.mode = ShareMode.off,
    this.activeCount = 0,
    this.totalCount = 0,
  });

  ShareState copyWith({
    bool? active,
    bool? probing,
    ShareMode? mode,
    int? activeCount,
    int? totalCount,
  }) =>
      ShareState(
        active: active ?? this.active,
        probing: probing ?? this.probing,
        mode: mode ?? this.mode,
        activeCount: activeCount ?? this.activeCount,
        totalCount: totalCount ?? this.totalCount,
      );
}

// ─── Notifier (mock-backed) ──────────────────────────────────────────────────

class ShareNotifier extends Notifier<ShareState> {
  // Persisted in real impl; in-process for the prototype so the disclosure
  // re-fires on app restart and is easy to demo.
  bool _smcAck = false;

  StreamSubscription? _appEventSub;
  int _workerSeq = 0;
  final Map<String, int> _sourceToWorker = {};

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
  Future<void> toggle(BuildContext context, WidgetRef widgetRef) async {
    if (state.active || state.probing) {
      await _stop(widgetRef);
      return;
    }

    state = state.copyWith(probing: true);

    // MOCK: real impl will FFI into radiance/portforward to probe UPnP.
    // Coin-flip the result so the demo exercises both the SmC and Unbounded
    // paths across runs; flip to `true` for the SmC path while iterating on
    // the disclosure copy.
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

  Future<void> _start(WidgetRef widgetRef, ShareMode mode) async {
    state = ShareState(
      active: true,
      probing: false,
      mode: mode,
      activeCount: 0,
      totalCount: 0,
    );
    _startEventSubscription(widgetRef);
    if (mode == ShareMode.smc) {
      // Flip the radiance peer-proxy setting; LocalBackend.PatchSettings
      // routes that into peer.Client.Start, which spins up the UPnP map,
      // registers with lantern-cloud, runs the samizdat inbound, and (via
      // the lantern-box peerconn listener radiance/peer/peer.go now sets)
      // emits ConnectionEvents that ride the radiance event bus → core.go
      // listenPeerConnectionEvents → FlutterEvent → our Dart subscription.
      await widgetRef
          .read(radianceSettingsProvider.notifier)
          .setPeerProxy(true);
    }
    // Unbounded mode is UI-only on this branch; broflake plumbing follows
    // when radiance#336 lands.
  }

  Future<void> _stop(WidgetRef widgetRef) async {
    _stopEventSubscription();
    final wasSmc = state.mode == ShareMode.smc;
    state = const ShareState();
    if (wasSmc) {
      await widgetRef
          .read(radianceSettingsProvider.notifier)
          .setPeerProxy(false);
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
    _sourceToWorker.clear();
    _appEventSub = widgetRef
        .read(lanternServiceProvider)
        .watchAppEvents()
        .listen((event) {
      if (event.eventType != 'peer-connection') return;
      try {
        final payload = jsonDecode(event.message) as Map<String, dynamic>;
        final eventState = (payload['state'] as num?)?.toInt() ?? 0;
        final source = (payload['source'] as String?) ?? '';
        // Globe only cares about the IP — strip ":port".
        final ip = source.split(':').first;
        if (ip.isEmpty) return;

        if (eventState == 1) {
          // Each (source IP) gets a stable worker idx so the matching
          // disconnect can find the arc to remove. Repeated +1 from the
          // same source (re-connect after disconnect) gets a new idx.
          if (_sourceToWorker.containsKey(ip)) return;
          final widx = _workerSeq++;
          _sourceToWorker[ip] = widx;
          _eventController.add(UnboundedConnectionEvent(
            state: 1,
            workerIdx: widx,
            addr: ip,
          ));
          state = state.copyWith(
            activeCount: state.activeCount + 1,
            totalCount: state.totalCount + 1,
          );
        } else if (eventState == -1) {
          final widx = _sourceToWorker.remove(ip);
          if (widx == null) return;
          _eventController.add(UnboundedConnectionEvent(
            state: -1,
            workerIdx: widx,
            addr: '',
          ));
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

  void _stopEventSubscription() {
    _appEventSub?.cancel();
    _appEventSub = null;
    _sourceToWorker.clear();
    _workerSeq = 0;
  }
}

final shareProvider =
    NotifierProvider<ShareNotifier, ShareState>(ShareNotifier.new);

// ─── Screen ──────────────────────────────────────────────────────────────────

class ShareMyConnectionScreen extends HookConsumerWidget {
  const ShareMyConnectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(shareProvider);
    final notifier = ref.read(shareProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    return BaseScreen(
      title: 'Share My Connection',
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Text(
              'Help others bypass censorship by sharing a small portion of '
              'your home internet connection. While sharing is on, traffic '
              'from users in censored regions will egress through your IP.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Expanded(
              flex: 3,
              child: _GlobeView(),
            ),
            const SizedBox(height: 8),
            _StatusCard(state: state, onToggle: () => notifier.toggle(context, ref)),
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
    final modeLabel = switch (state.mode) {
      ShareMode.off => state.probing ? 'Probing your network…' : 'Off',
      ShareMode.unbounded =>
        'Active — sharing via Unbounded (WebRTC)',
      ShareMode.smc =>
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Stat(label: 'Active now', value: '${state.activeCount}'),
                _Stat(label: 'Total today', value: '${state.totalCount}'),
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

  @override
  void initState() {
    super.initState();
    _globeController.onLoaded = () {
      if (!mounted) return;
      _applyTheme();
    };
    _initOrigin();
    _eventSub = ref
        .read(shareProvider.notifier)
        .connectionEvents
        .listen(_handleEvent);
  }

  @override
  void dispose() {
    _eventSub?.cancel();
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

  Future<void> _handleEvent(UnboundedConnectionEvent event) async {
    if (event.state == 1 && event.addr.isNotEmpty) {
      await _addPeer(event.workerIdx, event.addr);
    } else if (event.state == -1) {
      _removePeer(event.workerIdx);
    }
  }

  Future<void> _addPeer(int workerIdx, String addr) async {
    final coords = await GeoLookupService.peerLookup(addr);
    if (!mounted) return;
    _globeController.addPointConnection(PointConnection(
      id: 'conn_$workerIdx',
      start: _originCoords ?? const GlobeCoordinates(0, 0),
      end: coords,
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
      id: 'peer_$workerIdx',
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
