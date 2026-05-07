// Share My Connection — UX prototype.
// One unified screen for both protocols (Unbounded / Share-My-Connection):
//   - Toggle ON triggers a (mocked) UPnP probe.
//   - If UPnP works AND the user accepts the SmC disclosure, run SmC mode.
//   - Otherwise fall back to Unbounded mode.
//   - Globe animates connection arcs from a stream of UnboundedConnectionEvent.
//
// All wire-up to radiance / FFI is stubbed for this prototype: the UPnP probe
// returns success after a short delay, and connection events are fired by a
// timer cycling through a small set of canned residential peer IPs so the
// globe actually animates while the screen is visible.

import 'dart:async';
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

  Timer? _mockTimer;
  int _workerSeq = 0;
  final List<int> _activeWorkers = [];

  final _eventController =
      StreamController<UnboundedConnectionEvent>.broadcast();
  Stream<UnboundedConnectionEvent> get connectionEvents =>
      _eventController.stream;

  @override
  ShareState build() {
    ref.onDispose(() {
      _stopMockEvents();
      _eventController.close();
    });
    return const ShareState();
  }

  /// Toggle entry point. Caller passes its BuildContext so we can show the
  /// disclosure modal inline.
  Future<void> toggle(BuildContext context) async {
    if (state.active || state.probing) {
      _stop();
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
      _start(ShareMode.unbounded);
      return;
    }

    if (_smcAck) {
      _start(ShareMode.smc);
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
      _start(ShareMode.smc);
    } else {
      _start(ShareMode.unbounded);
    }
  }

  void _start(ShareMode mode) {
    state = ShareState(
      active: true,
      probing: false,
      mode: mode,
      activeCount: 0,
      totalCount: 0,
    );
    _startMockEvents();
  }

  void _stop() {
    _stopMockEvents();
    state = const ShareState();
  }

  // ── Mock connection event source ───────────────────────────────────────────
  // A small canned set of (country, IP) pairs heavy on Lantern's priority
  // censored regions, so the globe shows arcs landing where users actually
  // benefit from the network. Real impl will subscribe to a radiance event.

  static const _peerIPs = [
    '5.190.10.5', // IR
    '120.196.10.5', // CN
    '95.165.10.5', // RU
    '85.159.10.5', // TR
    '113.161.10.5', // VN
    '111.68.10.5', // PK
    '156.197.10.5', // EG
    '103.81.10.5', // MM
    '37.156.10.5', // IR (second)
    '202.108.10.5', // CN (second)
  ];

  void _startMockEvents() {
    final rand = Random();
    _mockTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      // Bias toward connecting until we have ~4 active, then 50/50 churn.
      final shouldConnect =
          _activeWorkers.length < 4 || rand.nextDouble() < 0.5;

      if (shouldConnect) {
        final addr = _peerIPs[rand.nextInt(_peerIPs.length)];
        final widx = _workerSeq++;
        _activeWorkers.add(widx);
        _eventController.add(UnboundedConnectionEvent(
          state: 1,
          workerIdx: widx,
          addr: addr,
        ));
        state = state.copyWith(
          activeCount: state.activeCount + 1,
          totalCount: state.totalCount + 1,
        );
      } else if (_activeWorkers.isNotEmpty) {
        final widx = _activeWorkers.removeAt(0);
        _eventController.add(UnboundedConnectionEvent(
          state: -1,
          workerIdx: widx,
          addr: '',
        ));
        state = state.copyWith(
          activeCount: max(0, state.activeCount - 1),
        );
      }
    });
  }

  void _stopMockEvents() {
    _mockTimer?.cancel();
    _mockTimer = null;
    _activeWorkers.clear();
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
            _StatusCard(state: state, onToggle: () => notifier.toggle(context)),
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
              Switch(
                value: state.active || state.probing,
                onChanged: state.probing ? null : (_) => onToggle(),
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
        final radius =
            min(constraints.maxWidth, constraints.maxHeight) / 2 * 0.7;
        return FlutterEarthGlobe(
          controller: _globeController,
          radius: radius,
          alignment: Alignment.center,
          onZoomChanged: (_) {},
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
