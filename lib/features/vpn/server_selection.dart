import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fpdart/fpdart.dart' show Either;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/models/latency_status.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/core/utils/helper_tags.dart';
import 'package:lantern/core/widgets/app_text.dart';
import 'package:lantern/core/widgets/expansion_chevron.dart';
import 'package:lantern/core/widgets/spinner.dart';
import 'package:lantern/features/helpers/personal_proxy_invite.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';
import 'package:lantern/features/macos_extension/provider/macos_extension_notifier.dart';
import 'package:lantern/features/vpn/latency_indicator.dart';
import 'package:lantern/features/vpn/personal_proxies_section.dart';
import 'package:lantern/features/vpn/provider/available_servers_notifier.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/features/vpn/single_city_server_view.dart';
import 'package:loader_overlay/loader_overlay.dart';

@RoutePage(name: 'ServerSelection')
class ServerSelection extends ConsumerStatefulWidget {
  const ServerSelection({super.key});

  @override
  ConsumerState<ServerSelection> createState() => _ServerSelectionState();
}

class _ServerSelectionState extends ConsumerState<ServerSelection> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref
            .read(availableServersProvider.notifier)
            .refreshAvailableServersAfterProbeSettle(),
      );
      // refreshIfUsed, never refresh: opening the list must not touch the
      // keystore.
      unawaited(ref.read(helpersProvider.notifier).refreshIfUsed());
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(serverLocationProvider);
    final availableServers = ref.watch(availableServersProvider);
    final isUserPro = ref.watch(isUserProProvider);

    return BaseScreen(
      key: const Key('server_selection.screen'),
      title: '',
      appBar: CustomAppBar(
        title: Text('server_selection'.i18n),
        actions: [
          IconButton(
            key: const Key('server_selection.more_options'),
            icon: const Icon(Icons.more_vert),
            onPressed: onOpenMoreOptions,
          ),
        ],
      ),
      body: availableServers.when(
        loading: () => const Center(child: Spinner()),
        error: (error, _) =>
            Center(child: Text(error.toString(), textAlign: TextAlign.center)),
        data: (servers) => _buildBody(servers, selected, isUserPro),
      ),
    );
  }

  Widget _buildBody(
    AvailableServers servers,
    ServerLocation selected,
    bool isUserPro,
  ) {
    final hasPersonalProxies = ref.watch(
      helpersProvider.select((s) => s.view.helpers.isNotEmpty),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSmartLocation(servers, selected),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'smart_routing_mode_description'.i18n,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium!.copyWith(color: context.textSecondary),
          ),
        ),
        const SizedBox(height: size24),
        Expanded(
          child: servers.hasUserServers || hasPersonalProxies
              ? _buildTabs(servers, isUserPro)
              : ServerLocationListView(servers: servers, userPro: isUserPro),
        ),
      ],
    );
  }

  Widget _buildTabs(AvailableServers servers, bool isUserPro) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 35.h,
            child: TabBar(
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: EdgeInsets.symmetric(horizontal: size24),
              splashBorderRadius: BorderRadius.circular(40),
              labelColor: context.actionTabbarSelectedText,
              dividerHeight: 0,
              unselectedLabelColor: context.actionTabbarDisabledText,
              labelStyle: Theme.of(context).textTheme.titleSmall,
              indicator: BoxDecoration(
                color: context.actionTabbarBg,
                borderRadius: BorderRadius.circular(40),
                shape: BoxShape.rectangle,
                border: Border.all(color: AppColors.blue3, width: 1),
              ),
              tabs: [
                Tab(child: Text('lantern_servers'.i18n)),
                Tab(
                  key: const Key('server_selection.private_servers_tab'),
                  child: Text('private_locations'.i18n),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const DividerSpace(padding: EdgeInsets.zero),
          const SizedBox(height: defaultSize),
          Expanded(
            child: TabBarView(
              children: [
                ServerLocationListView(servers: servers, userPro: isUserPro),
                const PrivateServerLocationListView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartLocation(
    AvailableServers servers,
    ServerLocation serverLocation,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final autoLocation = serverLocation.autoLocation;
    final displayName = autoLocation?.displayName ?? 'fastest_server'.i18n;
    final flag = autoLocation?.countryCode ?? '';
    final protocol = autoLocation?.protocol ?? '';
    final autoTag = autoLocation?.tag;
    final autoServer = autoTag == null ? null : servers.serverByTag(autoTag);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'smart_location'.i18n,
            style: textTheme.labelLarge!.copyWith(color: context.textSecondary),
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: AppTile(
            icon: flag.isEmpty
                ? AppImagePaths.location
                : Flag(countryCode: flag),
            label: displayName.i18n,
            onPressed: onSmartLocation,
            subtitle: protocol.isEmpty
                ? null
                : Text(
                    protocol.capitalize,
                    style: textTheme.labelMedium!.copyWith(
                      color: context.textTertiary,
                    ),
                  ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                if (autoServer != null)
                  LatencyIndicator(status: LatencyStatus.of(autoServer)),
                AppImage(
                  path: AppImagePaths.blot,
                  color: context.statusWarningBgDot,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> onSmartLocation() async {
    if (!_macOSExtensionReady(ref)) return;

    final type = ref
        .read(serverLocationProvider)
        .serverType
        .toServerLocationType;
    if (type == ServerLocationType.auto) {
      appLogger.debug(
        'Already in smart location, no need to switch, Just pop the screen',
      );
      appRouter.popUntilRoot();
      return;
    }

    // Tapping here means switch to auto regardless of the VPN state.
    final locationNotifier = ref.read(serverLocationProvider.notifier);
    await _connectAndReturnHome(
      context,
      ref,
      attempt: (skipConflictCheck) => ref
          .read(vpnProvider.notifier)
          .startVPN(force: true, skipConflictCheck: skipConflictCheck),
      save: locationNotifier.switchToAuto,
    );
  }

  void onOpenMoreOptions() {
    showAppBottomSheet(
      context: context,
      title: 'private_server_options'.i18n,
      scrollControlDisabledMaxHeightRatio: .4,
      builder: (sheetContext, scrollController) => PrivateLocationsMenu(
        onInvitePersonalProxy: () {
          Navigator.of(sheetContext).pop();
          startPersonalProxyInvite(context, ref);
        },
      ),
    );
  }
}

/// The server list's menu: set up, join, invite a personal proxy, manage.
class PrivateLocationsMenu extends ConsumerWidget {
  const PrivateLocationsMenu({super.key, required this.onInvitePersonalProxy});

  final VoidCallback onInvitePersonalProxy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invites = ref.watch(helperInvitesAvailableProvider);
    return ListView(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      children: [
        AppTile(
          tileKey: const Key('server_selection.setup_private_server'),
          label: 'setup_private_server'.i18n,
          onPressed: () => context.pushRoute(PrivateServerSetup()),
        ),
        const DividerSpace(padding: EdgeInsets.zero),
        AppTile(
          tileKey: const Key('server_selection.join_private_server'),
          label: 'join_a_private_server'.i18n,
          onPressed: () => context.pushRoute(JoinPrivateServer()),
        ),
        if (invites) ...[
          const DividerSpace(padding: EdgeInsets.zero),
          AppTile(
            tileKey: const Key('server_selection.invite_personal_proxy'),
            label: 'invite_personal_proxy'.i18n,
            onPressed: onInvitePersonalProxy,
          ),
        ],
        const DividerSpace(padding: EdgeInsets.zero),
        AppTile(
          tileKey: const Key('server_selection.manage_private_servers'),
          label: 'manage_private_locations'.i18n,
          onPressed: () => context.pushRoute(ManagePrivateServer()),
        ),
      ],
    );
  }
}

class ServerLocationListView extends ConsumerStatefulWidget {
  final AvailableServers servers;
  final bool userPro;

  const ServerLocationListView({
    super.key,
    required this.servers,
    required this.userPro,
  });

  @override
  ConsumerState<ServerLocationListView> createState() =>
      _ServerLocationListViewState();
}

class _ServerLocationListViewState
    extends ConsumerState<ServerLocationListView> {
  @override
  Widget build(BuildContext context) {
    final selectedTag = ref.watch(serverLocationProvider).serverName;
    final locations = widget.servers.lanternServerLocations;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.userPro) ...[
            ProBanner(topMargin: 0),
            const SizedBox(height: 12),
          ],
          Flexible(
            child: locations.isEmpty
                ? const Center(child: Text("No locations available"))
                : Stack(
                    children: [
                      ScrollConfiguration(
                        behavior: ScrollConfiguration.of(
                          context,
                        ).copyWith(scrollbars: false),
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 4.0,
                                left: defaultSize,
                              ),
                              child: HeaderText('pro_locations'.i18n),
                            ),
                            AppCard(
                              padding: EdgeInsets.zero,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: _locationTiles(
                                  locations,
                                  selectedTag,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!ref.watch(canSelectServerProvider))
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: context.bgElevated.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.center,
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// One row per country, divider-separated, with multi-city countries folded
  /// into an expandable group row.
  List<Widget> _locationTiles(List<Server> locations, String selectedTag) {
    // lanternServerLocations is already sorted by country, so grouping keeps
    // the countries in order.
    final byCountry = <String, List<Server>>{};
    for (final server in locations) {
      byCountry.putIfAbsent(server.location.country, () => []).add(server);
    }

    final tiles = byCountry.values.map((countryLocations) {
      if (countryLocations.length == 1) {
        final server = countryLocations.first;
        return SingleCityServerView(
          key: ValueKey(server.tag),
          onServerSelected: onServerSelected,
          server: server,
          isSelected: selectedTag == server.tag,
        );
      }
      return _CountryCityListView(
        locations: countryLocations,
        selectedServerTag: selectedTag,
        onServerSelected: onServerSelected,
      );
    });

    return [
      for (final (i, tile) in tiles.indexed) ...[
        if (i > 0) const DividerSpace(),
        tile,
      ],
    ];
  }

  Future<void> onServerSelected(Server server) async {
    if (!_macOSExtensionReady(ref)) return;

    final locationNotifier = ref.read(serverLocationProvider.notifier);
    await _connectAndReturnHome(
      context,
      ref,
      attempt: (skipConflictCheck) => ref
          .read(vpnProvider.notifier)
          .connectToServer(
            ServerLocationType.lanternLocation,
            server.tag,
            skipConflictCheck: skipConflictCheck,
          ),
      save: () => locationNotifier.updateServerLocation(
        ServerLocation.fromServer(server: server),
      ),
    );
  }
}

class _CountryCityListView extends StatefulWidget {
  final List<Server> locations;
  final String selectedServerTag;
  final ValueChanged<Server> onServerSelected;

  const _CountryCityListView({
    required this.locations,
    required this.selectedServerTag,
    required this.onServerSelected,
  });

  String get country => locations.first.location.country;

  @override
  State<_CountryCityListView> createState() => _CountryCityListViewState();
}

class _CountryCityListViewState extends State<_CountryCityListView> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final countryCode = widget.locations.first.location.countryCode;
    final best = LatencyStatus.best(widget.locations);

    if (PlatformUtils.isDesktop) {
      return Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          enableFeedback: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          childrenPadding: const EdgeInsets.symmetric(
            vertical: 0,
            horizontal: 0,
          ),
          leading: Flag(countryCode: countryCode),
          title: Text(
            widget.country,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge!.copyWith(color: context.textPrimary),
          ),
          onExpansionChanged: (expanded) {
            setState(() => _isExpanded = expanded);
          },
          trailing: LatencyTrailing(
            status: best,
            chevron: ExpansionChevron(isExpanded: _isExpanded),
          ),
          shape: const RoundedRectangleBorder(side: BorderSide.none),
          children: widget.locations.map((server) {
            return AppTile(
              dense: true,
              minHeight: 58,
              // end matches the country tile's 16px tilePadding so the
              // latency columns align exactly; directional so RTL keeps the
              // city indent on the leading side.
              contentPadding: const EdgeInsetsDirectional.only(
                start: 53,
                end: 16,
              ),
              label: server.location.city,
              subtitle: server.type.isEmpty
                  ? null
                  : Text(
                      server.type.capitalize,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium!.copyWith(
                        color: context.textSecondary,
                      ),
                    ),
              tileTextStyle: Theme.of(
                context,
              ).textTheme.bodyMedium!.copyWith(color: context.textPrimary),
              trailing: LatencyTrailing(status: LatencyStatus.of(server)),
              onPressed: () => widget.onServerSelected(server),
            );
          }).toList(),
        ),
      );
    }

    return AppTile(
      icon: Flag(countryCode: countryCode),
      label: widget.country,
      trailing: LatencyTrailing(
        status: best,
        chevron: AppImage(
          path: AppImagePaths.arrowForward,
          height: 20.0,
          color: context.textPrimary,
        ),
      ),
      onPressed: () => _showCountryBottomSheet(context),
    );
  }

  void _showCountryBottomSheet(BuildContext context) {
    showAppBottomSheet(
      context: context,
      title: widget.country,
      scrollControlDisabledMaxHeightRatio: 0.45,
      builder: (bottomSheetContext, scrollController) {
        return Flexible(
          child: CountryCitySheetList(
            country: widget.country,
            initialLocations: widget.locations,
            selectedServerTag: widget.selectedServerTag,
            scrollController: scrollController,
            onServerSelected: (selected) {
              Navigator.of(bottomSheetContext).pop();
              widget.onServerSelected(selected);
            },
          ),
        );
      },
    );
  }
}

/// The city rows inside a country's bottom sheet. The sheet is its own route,
/// so it watches [availableServersProvider] itself; otherwise probe refreshes
/// that land while it's open would leave its latency indicators stale.
/// [initialLocations] is used only while there's no server data at all; a
/// refresh that drops the country empties the list rather than resurrecting
/// cities that are gone.
class CountryCitySheetList extends ConsumerWidget {
  final String country;
  final List<Server> initialLocations;
  final String selectedServerTag;
  final ScrollController? scrollController;
  final ValueChanged<Server> onServerSelected;

  const CountryCitySheetList({
    super.key,
    required this.country,
    required this.initialLocations,
    required this.selectedServerTag,
    required this.onServerSelected,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref
        .watch(availableServersProvider)
        .value
        ?.lanternServerLocations
        .where((s) => s.location.country == country)
        .toList();
    final locations = current ?? initialLocations;

    return ListView.separated(
      controller: scrollController,
      padding: EdgeInsets.zero,
      itemCount: locations.length,
      separatorBuilder: (_, _) => const DividerSpace(padding: EdgeInsets.zero),
      itemBuilder: (_, index) {
        final server = locations[index];
        return SingleCityServerView(
          key: ValueKey(server.tag),
          nested: true,
          onServerSelected: onServerSelected,
          server: server,
          isSelected: selectedServerTag == server.tag,
        );
      },
    );
  }
}

/// How often the Private Locations tab refreshes helper presence.
const personalProxiesRefreshInterval = Duration(seconds: 60);

class PrivateServerLocationListView extends StatefulHookConsumerWidget {
  const PrivateServerLocationListView({super.key});

  @override
  ConsumerState<PrivateServerLocationListView> createState() =>
      _PrivateServerLocationListViewState();
}

class _PrivateServerLocationListViewState
    extends ConsumerState<PrivateServerLocationListView> {
  TextTheme? _textTheme;

  @override
  Widget build(BuildContext context) {
    _textTheme = Theme.of(context).textTheme;

    final availableServers = ref.watch(availableServersProvider);
    final selected = ref.watch(serverLocationProvider);
    final hasPersonalProxies = ref.watch(
      helpersProvider.select((s) => s.view.helpers.isNotEmpty),
    );

    // Helpers stop polling once nothing is pending, so a friend coming
    // online would leave the Personal proxies row disabled. TabBarView
    // builds this only while the tab is shown. refreshIfUsed, never
    // refresh: the list must not touch the keystore.
    useEffect(() {
      if (!hasPersonalProxies) return null;
      final timer = Timer.periodic(personalProxiesRefreshInterval, (_) {
        if (WidgetsBinding.instance.lifecycleState !=
            AppLifecycleState.resumed) {
          return;
        }
        unawaited(ref.read(helpersProvider.notifier).refreshIfUsed());
      });
      return timer.cancel;
    }, [hasPersonalProxies]);

    if (availableServers.isLoading) {
      return const Center(child: Spinner());
    }

    final err = availableServers.asError;
    if (err != null) {
      return Center(
        child: Text(err.error.toString(), textAlign: TextAlign.center),
      );
    }

    final userLocations = availableServers.requireValue.userServers;
    final selectedTag = selected.serverName;
    final personalSelected =
        selected.serverType.toServerLocationType ==
        ServerLocationType.personalProxy;

    if (userLocations.isEmpty && !hasPersonalProxies) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'no_private_server_setup_yet'.i18n,
            textAlign: TextAlign.center,
            style: _textTheme!.titleSmall!.copyWith(color: AppColors.gray8),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'setup_private_server'.i18n,
            onPressed: () => context.pushRoute(VPNSetting()),
          ),
        ],
      );
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const SizedBox(height: 16),
        PersonalProxiesSection(
          selected: personalSelected,
          onSelect: () => _select(
            ServerLocationType.personalProxy,
            personalProxiesTag,
            ServerLocation.personalProxy(),
          ),
        ),
        if (userLocations.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: HeaderText('your_server'.i18n),
          ),
          const SizedBox(height: 8),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, server) in userLocations.indexed) ...[
                  if (i > 0) const DividerSpace(),
                  _privateServerTile(server, selectedTag == server.tag),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _privateServerTile(Server server, bool isSelected) => AppTile(
    tileKey: Key('server_selection.private_server.${server.tag}'),
    onPressed: () {
      if (isSelected) {
        appLogger.debug('Already selected this server');
        context.showSnackBar('server_already_selected'.i18n);
        return;
      }
      onPrivateServerSelected(server);
    },
    icon: Flag(
      countryCode: server.location.countryCode,
      size: const Size(40, 28),
    ),
    label: server.tag,
    subtitle: Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text(
        '${server.location.city} - ${server.type}',
        style: _textTheme!.labelMedium!.copyWith(color: context.textTertiary),
      ),
    ),
    trailing: isSelected ? AppImage(path: AppImagePaths.blot) : null,
  );

  Future<void> onPrivateServerSelected(Server server) => _select(
    ServerLocationType.privateServer,
    server.tag,
    ServerLocation(
      serverType: ServerLocationType.privateServer.name,
      serverName: server.tag,
      country: server.location.country,
      city: server.location.city,
      countryCode: server.location.countryCode,
      protocol: server.type,
    ),
    connectedMessage: 'connected_to_private_server'.i18n,
  );

  /// Connects to [tag] and, once connected, makes [location] the selection.
  Future<void> _select(
    ServerLocationType type,
    String tag,
    ServerLocation location, {
    String? connectedMessage,
  }) async {
    final locationNotifier = ref.read(serverLocationProvider.notifier);
    await _connectAndReturnHome(
      context,
      ref,
      attempt: (skipConflictCheck) => ref
          .read(vpnProvider.notifier)
          .connectToServer(type, tag, skipConflictCheck: skipConflictCheck),
      save: () => locationNotifier.updateServerLocation(location),
      connectedMessage: connectedMessage,
    );
  }
}

/// On macOS the system extension must be approved before anything can
/// connect; shows the approval dialog and returns false while it isn't.
bool _macOSExtensionReady(WidgetRef ref) {
  if (!PlatformUtils.isMacOS) return true;
  if (ref.read(macosExtensionProvider).isReady) return true;
  appRouter.push(const MacOSExtensionDialog());
  return false;
}

/// The connect flow shared by every row on this screen. Runs [attempt] behind
/// the loading overlay, offers the conflict dialog and a retry when another
/// VPN is active, then hands [save] to the location notifier to run once the
/// VPN reports connected, and returns to the home screen.
Future<void> _connectAndReturnHome(
  BuildContext context,
  WidgetRef ref, {
  required Future<Either<Failure, String>> Function(bool skipConflictCheck)
  attempt,
  required FutureOr<void> Function() save,
  String? connectedMessage,
  bool skipConflictCheck = false,
}) async {
  final locationNotifier = ref.read(serverLocationProvider.notifier);
  // The overlay is app-wide, so hide it through its controller rather than
  // this context, which may be gone by the time the attempt returns.
  final overlay = context.loaderOverlay;
  overlay.show();
  final Either<Failure, String> result;
  try {
    result = await attempt(skipConflictCheck);
  } finally {
    overlay.hide();
  }
  result.fold(
    (failure) {
      if (!context.mounted) return;
      if (failure is VpnConflictFailure && !skipConflictCheck) {
        AppDialog.vpnConflictDialog(
          context: context,
          onConnectAnyway: () {
            appRouter.maybePop();
            unawaited(
              _connectAndReturnHome(
                context,
                ref,
                attempt: attempt,
                save: save,
                connectedMessage: connectedMessage,
                skipConflictCheck: true,
              ),
            );
          },
        );
        return;
      }
      context.showSnackBar(failure.localizedErrorMessage);
    },
    (_) => unawaited(
      _returnHomeOnceSaved(context, locationNotifier, save, connectedMessage),
    ),
  );
}

/// Waits for the notifier to save the selection on connect, then returns home
/// if this screen is still showing. A retired request leaves the screen alone.
Future<void> _returnHomeOnceSaved(
  BuildContext context,
  ServerLocationNotifier locationNotifier,
  FutureOr<void> Function() save,
  String? connectedMessage,
) async {
  final saved = await locationNotifier.saveOnceConnected(save);
  if (!saved || !context.mounted) return;
  if (connectedMessage != null) context.showSnackBar(connectedMessage);
  appRouter.popUntilRoot();
}
