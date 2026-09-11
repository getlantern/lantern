import 'dart:async';
import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter_earth_globe/flutter_earth_globe.dart';
import 'package:flutter_earth_globe/flutter_earth_globe_controller.dart';
import 'package:flutter_earth_globe/globe_coordinates.dart';
import 'package:flutter_earth_globe/point.dart';
import 'package:flutter_earth_globe/point_connection.dart';
import 'package:flutter_earth_globe/point_connection_style.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/action_mode_connection_event.dart';
import 'package:lantern/core/services/geo_lookup_service.dart';
import 'package:lantern/features/action_mode/provider/share_notifier.dart';
import 'package:lantern/features/action_mode/provider/action_mode_tab_visible_notifier.dart';

/// Globe drawing an arc from each connected peer's country to the user's own
/// location, fed by ShareNotifier.connectionEvents.
class ActionModeGlobe extends ConsumerStatefulWidget {
  const ActionModeGlobe({super.key});

  @override
  ConsumerState<ActionModeGlobe> createState() => _ActionModeGlobeState();
}

class _ActionModeGlobeState extends ConsumerState<ActionModeGlobe> {
  // The spec's arcs are a cyan-to-yellow gradient; the package only supports
  // flat colours, so alternate the two ends by workerIdx.
  static final _arcColors = [
    AppColors.blue4.withValues(alpha: 0.75),
    AppColors.yellow3.withValues(alpha: 0.75),
  ];
  static final _originPointColor = AppColors.blue4.withValues(alpha: 0.15);
  static const _peerPointColor = AppColors.green6;
  static const _atmosphereDark = AppColors.blue4;
  static const _atmosphereLight = AppColors.blue6;
  // Brief connections (URL-test probes) keep their arc long enough to be seen.
  static const _arcLinger = Duration(seconds: 5);

  final FlutterEarthGlobeController _globeController =
      FlutterEarthGlobeController(
    isRotating: true,
    rotationSpeed: 0.02,
    zoom: 0,
    isZoomEnabled: false,
    showAtmosphere: true,
    atmosphereColor: _atmosphereDark,
    atmosphereOpacity: 0.18,
    atmosphereBlur: 22,
    // Mostly ambient so the light texture doesn't render as a grey ball.
    ambientLight: 0.97,
    lightIntensity: 0.15,
  );

  StreamSubscription<ActionModeConnectionEvent>? _eventSub;
  GlobeCoordinates? _originCoords;
  final Map<int, Timer> _pendingRemovals = {};
  // Everything on the globe, so a stop can clear it without -1 events.
  final Set<int> _drawn = {};
  Brightness? _appliedBrightness;

  @override
  void initState() {
    super.initState();
    // Subscribe before the origin lookup so nothing is missed; _addPeer skips
    // draws until origin is known and _initOrigin replays them.
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
    // The globe widget disposes the controller's animation itself.
    super.dispose();
  }

  // Theme must be read where a dependency is registered; macOS can change
  // platformBrightness after the first frame.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    if (brightness == _appliedBrightness) return;
    _appliedBrightness = brightness;
    // Controller setters notify synchronously; defer past the build phase.
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
    _globeController.focusOnCoordinates(coords, animate: false);
    ref.read(shareProvider.notifier).replayCurrentPeers();
  }

  void _handleEvent(ActionModeConnectionEvent event) {
    if (event.state == 1 && event.coordinates != null) {
      _pendingRemovals.remove(event.workerIdx)?.cancel();
      _addPeer(event);
    } else if (event.state == -1) {
      _pendingRemovals[event.workerIdx]?.cancel();
      _pendingRemovals[event.workerIdx] = Timer(_arcLinger, () {
        _pendingRemovals.remove(event.workerIdx);
        if (!mounted) return;
        _removePeer(event.workerIdx);
      });
    }
  }

  // Deterministic per-peer offset so same-country arcs don't overlap.
  GlobeCoordinates _jittered(GlobeCoordinates base, int widx) {
    final hash = widx * 2654435761; // Knuth multiplicative hash
    final dLat = ((hash >> 4) & 0xff) / 255.0 * 4.0 - 2.0; // [-2, +2]°
    final dLng = ((hash >> 12) & 0xff) / 255.0 * 4.0 - 2.0;
    return GlobeCoordinates(base.latitude + dLat, base.longitude + dLng);
  }

  void _addPeer(ActionModeConnectionEvent event) {
    if (!mounted || _originCoords == null) return;
    final coords = _jittered(event.coordinates!, event.workerIdx);
    // dashAnimateTime stays 0: any other value keeps the package's repaint
    // loop running for as long as an arc exists.
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

  void _clearAllPeers() {
    for (final t in _pendingRemovals.values) {
      t.cancel();
    }
    _pendingRemovals.clear();
    for (final workerIdx in _drawn.toList()) {
      _removePeer(workerIdx);
    }
  }

  @override
  Widget build(BuildContext context) {
    // TickerMode freezes the spin and any in-flight turn while the tab is
    // off screen.
    final visible = ref.watch(actionModeTabVisibleProvider);
    // Stopping tears down the event stream without -1 events.
    ref.listen(shareProvider.select((s) => s.active), (prev, next) {
      if (prev == true && next == false) _clearAllPeers();
    });
    return TickerMode(
      enabled: visible,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The package positions the sphere relative to MediaQuery.size, so
          // override it with this slot's size to keep the sphere centred.
          final widgetSize = Size(constraints.maxWidth, constraints.maxHeight);
          // ~66% of the slot's width, clamped by height so a short slot still
          // leaves room for arcs above and the toast below.
          final radius = min(
            constraints.maxWidth * 0.33,
            constraints.maxHeight * 0.42,
          );
          return Stack(
            children: [
              // Shadow sits outside the ClipRect below, which would crop its
              // blur.
              Align(
                alignment: const Alignment(0.0, -0.1),
                child: Container(
                  width: radius * 2,
                  height: radius * 2,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x21006163),
                        offset: Offset(0, 4),
                        blurRadius: 64,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                // Keeps high-curving arcs inside the slot.
                child: ClipRect(
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(size: widgetSize),
                    child: FlutterEarthGlobe(
                      controller: _globeController,
                      radius: radius,
                      alignment: const Alignment(0.0, -0.1),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
