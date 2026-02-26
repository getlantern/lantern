import 'dart:async';
import 'dart:math';

import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_earth_globe/flutter_earth_globe.dart';
import 'package:flutter_earth_globe/flutter_earth_globe_controller.dart';
import 'package:flutter_earth_globe/globe_coordinates.dart';
import 'package:flutter_earth_globe/point.dart';
import 'package:flutter_earth_globe/point_connection.dart';
import 'package:flutter_earth_globe/point_connection_style.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/entity/app_setting_entity.dart';
import 'package:lantern/core/models/unbounded_connection_event.dart';
import 'package:lantern/core/services/geo_lookup_service.dart';
import 'package:lantern/core/widgets/info_row.dart';
import 'package:lantern/core/widgets/switch_button.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/unbounded/provider/unbounded_notifier.dart';

@RoutePage(name: 'UnboundedScreen')
class UnboundedScreen extends HookConsumerWidget {
  const UnboundedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = TextTheme.of(context);
    final appSetting = ref.watch(appSettingProvider);
    final settingNotifier = ref.read(appSettingProvider.notifier);
    final stats = ref.watch(unboundedProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!appSetting.unboundedWelcomeSeen) {
        settingNotifier.setUnboundedWelcomeSeen(true);
        _showWelcomeDialog(context);
      }
    });

    return BaseScreen(
      title: 'unbounded'.i18n,
      body: Column(
        children: [
          InfoRow(text: 'help_others_bypass_censorship'.i18n),
          SizedBox(height: defaultSize),
          Expanded(flex: 3, child: _GlobeView()),
          SizedBox(height: defaultSize),
          _buildStatusCard(
              context, appSetting, stats, settingNotifier, textTheme),
          SizedBox(height: defaultSize),
          _buildAutoEnableCard(context, appSetting, settingNotifier, textTheme),
          SizedBox(height: defaultSize),
        ],
      ),
    );
  }

  // ── Card builders ──────────────────────────────────────────────────────────

  Widget _buildStatusCard(
    BuildContext context,
    AppSetting appSetting,
    UnboundedStats stats,
    AppSettingNotifier notifier,
    TextTheme textTheme,
  ) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          AppTile(
            label: 'status'.i18n,
            labelWidget: Row(
              children: [
                Text(
                  '${'status'.i18n}: ',
                  style:
                      textTheme.bodyLarge!.copyWith(color: context.textPrimary),
                ),
                Text(
                  appSetting.unboundedEnabled
                      ? 'enabled'.i18n
                      : 'disabled'.i18n,
                  style: textTheme.titleMedium!.copyWith(
                    color: appSetting.unboundedEnabled
                        ? AppColors.green6
                        : context.textTertiary,
                  ),
                ),
              ],
            ),
            tileTextStyle: textTheme.bodyLarge,
            icon: Icon(Icons.language, color: context.textPrimary),
            trailing: SwitchButton(
              value: appSetting.unboundedEnabled,
              onChanged: notifier.setUnboundedEnabled,
            ),
          ),
          DividerSpace(),
          AppTile(
            label: 'people_you_are_helping_right_now'.i18n,
            tileTextStyle: textTheme.bodyLarge,
            icon: Icon(Icons.person_outline, color: context.textPrimary),
            trailing: Text(
              stats.activeCount.toString(),
              style: textTheme.titleMedium!.copyWith(color: context.textLink),
            ),
          ),
          DividerSpace(),
          AppTile(
            label: 'total_people_helped_to_date'.i18n,
            tileTextStyle: textTheme.bodyLarge!,
            icon: Icon(Icons.people, color: context.textPrimary),
            trailing: Text(
              stats.totalCount.toString(),
              style: textTheme.titleMedium!.copyWith(color: context.textLink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoEnableCard(
    BuildContext context,
    AppSetting appSetting,
    AppSettingNotifier notifier,
    TextTheme textTheme,
  ) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: AppTile(
        icon: AppImagePaths.autoMode,
        label: 'auto_enable_unbounded'.i18n,
        subtitle: Text(
          'turn_on_automatically_when_lantern_is_open'.i18n,
          style: textTheme.labelMedium!.copyWith(color: context.textTertiary),
        ),
        trailing: Checkbox(
          value: appSetting.autoEnableUnbounded,
          onChanged: (value) => notifier.setAutoEnableUnbounded(value!),
        ),
      ),
    );
  }

  // ── Welcome dialog ─────────────────────────────────────────────────────────

  void _showWelcomeDialog(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    AppDialog.customDialog(
      context: context,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 24),
          Icon(Icons.handshake_outlined, size: 48, color: context.textLink),
          const SizedBox(height: 16),
          Text(
            'welcome_to_unbounded'.i18n,
            style: textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'unbounded_description'.i18n,
            style: textTheme.bodyMedium!.copyWith(color: context.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'your_connection_stays_secure_and_private'.i18n,
            style: textTheme.bodyMedium!.copyWith(color: context.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      action: [
        AppTextButton(
          label: 'learn_more'.i18n,
          onPressed: () => UrlUtils.openUrl(AppUrls.unbounded),
        ),
        AppTextButton(
          label: 'got_it'.i18n,
          onPressed: () => appRouter.maybePop(),
        ),
      ],
    );
  }
}

// ── Globe widget ───────────────────────────────────────────────────────────────

class _GlobeView extends ConsumerStatefulWidget {
  @override
  ConsumerState<_GlobeView> createState() => _GlobeViewState();
}

class _GlobeViewState extends ConsumerState<_GlobeView> {
  // Arc: blue4 at 75 % opacity
  static final _arcColor = AppColors.blue4.withValues(alpha: 0.75);

  // Dots: blue4 (origin) and yellow3 (peer) both at 15 % opacity
  static final _originPointColor = AppColors.blue4.withValues(alpha: 0.15);
  static final _peerPointColor = AppColors.yellow3.withValues(alpha: 0.15);

  // Atmosphere: solid blue4 (dark theme) / blue6 (light theme)
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

    listingToConnectionEvents();
    _initOrigin();
  }

  void listingToConnectionEvents() {
    _eventSub = ref
        .read(unboundedProvider.notifier)
        .connectionEvents
        .listen(_handleConnectionEvent);
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _globeController.dispose();
    super.dispose();
  }

  void _applyTheme() {
    final isDark = context.isDark;
    _globeController.loadSurface(AssetImage(
      isDark ? AppImagePaths.darkMap : AppImagePaths.lightMap,
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

  Future<void> _handleConnectionEvent(UnboundedConnectionEvent event) async {
    if (event.state == 1 && event.addr.isNotEmpty) {
      await _addPeer(event.workerIdx, event.addr);
    } else if (event.state == -1) {
      _removePeer(event.workerIdx);
    }
  }

  Future<void> _addPeer(int workerIdx, String addr) async {
    final coords = await _resolveCoords(addr);
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

  Future<GlobeCoordinates> _resolveCoords(String addr) =>
      GeoLookupService.peerLookup(addr);

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // RotatingGlobe uses MediaQuery.size to center the sphere on screen.
        // We override it so the globe centers within this widget's bounds
        // rather than the full screen.
        final widgetSize = Size(constraints.maxWidth, constraints.maxHeight);

        // 70 % of the shorter edge keeps the atmosphere glow from being clipped.
        final radius =
            min(constraints.maxWidth, constraints.maxHeight) / 2 * 0.7;

        // ClipRect prevents arcs from painting outside this widget's box.
        return ClipRect(
          child: MediaQuery(
            data: MediaQueryData(size: widgetSize),
            child: Stack(
              children: [
                Positioned.fill(
                  child: FlutterEarthGlobe(
                    controller: _globeController,
                    radius: radius,
                    alignment: const Alignment(0.0, 0.1),
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
