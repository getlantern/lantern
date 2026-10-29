import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/models/lantern_status.dart';
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
import 'package:lantern/features/vpn/provider/vpn_status_notifier.dart';
import 'package:lantern/features/vpn/server_selection_callbacks.dart';
import 'package:lantern/features/vpn/single_city_server_view.dart';

@RoutePage(name: 'ServerSelection')
class ServerSelection extends StatefulHookConsumerWidget {
  const ServerSelection({super.key});

  @override
  ConsumerState<ServerSelection> createState() => _ServerSelectionState();
}

class _ServerSelectionState extends ConsumerState<ServerSelection> {
  TextTheme? _textTheme;

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

    _textTheme = TextTheme.of(context);

    final appBar = CustomAppBar(
      title: Text('server_selection'.i18n),
      actions: [
        IconButton(
          key: const Key('server_selection.more_options'),
          icon: const Icon(Icons.more_vert),
          onPressed: onOpenMoreOptions,
        ),
      ],
    );

    if (availableServers.isLoading) {
      return BaseScreen(
        key: const Key('server_selection.screen'),
        title: '',
        appBar: appBar,
        body: const Center(child: Spinner()),
      );
    }

    final err = availableServers.asError;
    if (err != null) {
      return BaseScreen(
        key: const Key('server_selection.screen'),
        title: '',
        appBar: appBar,
        body: Center(
          child: Text(err.error.toString(), textAlign: TextAlign.center),
        ),
      );
    }

    final selectedServer = selected;
    final hasPersonalProxies = ref.watch(
      helpersProvider.select((s) => s.view.helpers.isNotEmpty),
    );
    final isPrivateServerFound =
        availableServers.requireValue.hasUserServers || hasPersonalProxies;

    return BaseScreen(
      key: const Key('server_selection.screen'),
      title: '',
      appBar: appBar,
      body: isPrivateServerFound
          ? _buildBody(selectedServer, isUserPro)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSmartLocation(selectedServer),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'smart_routing_mode_description'.i18n,
                    style: _textTheme?.bodyMedium!.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: size24),
                Flexible(child: ServerLocationListView(userPro: isUserPro)),
              ],
            ),
    );
  }

  Widget _buildBody(ServerLocation selectedServer, bool isUserPro) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildSmartLocation(selectedServer),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'smart_routing_mode_description'.i18n,
              style: _textTheme?.bodyMedium!.copyWith(
                color: context.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: size24),
          SizedBox(
            height: 35.h,
            child: TabBar(
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: EdgeInsets.symmetric(horizontal: size24),
              splashBorderRadius: BorderRadius.circular(40),
              labelColor: context.actionTabbarSelectedText,
              dividerHeight: 0,
              unselectedLabelColor: context.actionTabbarDisabledText,
              labelStyle: _textTheme!.titleSmall,
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
                ServerLocationListView(userPro: isUserPro),
                const PrivateServerLocationListView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartLocation(ServerLocation serverLocation) {
    final autoLocation = serverLocation.autoLocation;
    final displayName = autoLocation?.displayName ?? 'fastest_server'.i18n;
    final flag = autoLocation?.countryCode ?? '';
    final protocol = autoLocation?.protocol ?? '';
    final autoTag = autoLocation?.tag;
    final autoServer = autoTag == null
        ? null
        : ref.watch(availableServersProvider).value?.serverByTag(autoTag);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'smart_location'.i18n,
            style: _textTheme?.labelLarge!.copyWith(
              color: context.textSecondary,
            ),
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
                    style: _textTheme!.labelMedium!.copyWith(
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
    if (PlatformUtils.isMacOS) {
      final macosExtensionStatus = ref.read(macosExtensionProvider);
      if (!macosExtensionStatus.isReady) {
        appRouter.push(const MacOSExtensionDialog());
        return;
      }
    }

    final serverLocation = ref.read(serverLocationProvider);

    final type = serverLocation.serverType.toServerLocationType;
    if (type == ServerLocationType.auto) {
      appLogger.debug(
        'Already in smart location, no need to switch, Just pop the screen',
      );
      appRouter.popUntilRoot();
      return;
    }

    /// User clicking here mean user want to switch to auto server regardless of VPN state
    final result = await ref.read(vpnProvider.notifier).startVPN(force: true);

    result.fold(
      (failure) {
        if (failure is VpnConflictFailure) {
          if (!context.mounted) {
            return;
          }
          AppDialog.vpnConflictDialog(
            context: context,
            onConnectAnyway: () async {
              appRouter.maybePop();
              final retryResult = await ref
                  .read(vpnProvider.notifier)
                  .startVPN(skipConflictCheck: true, force: true);
              if (!context.mounted) return;
              retryResult.fold((failure) {
                context.showSnackBar(failure.localizedErrorMessage);
                appLogger.error("Error changing VPN state: ${failure.error}");
              }, (_) => appRouter.popUntilRoot());
            },
          );
        } else {
          context.showSnackBar(failure.localizedErrorMessage);
        }
      },
      (_) async {
        await ref.read(serverLocationProvider.notifier).switchToAuto();
        appRouter.popUntilRoot();
      },
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

class ServerLocationListView extends StatefulHookConsumerWidget {
  final bool userPro;

  const ServerLocationListView({super.key, required this.userPro});

  @override
  ConsumerState<ServerLocationListView> createState() =>
      _ServerLocationListViewState();
}

class _ServerLocationListViewState
    extends ConsumerState<ServerLocationListView> {
  @override
  Widget build(BuildContext context) {
    final availableServers = ref.watch(availableServersProvider);
    final selected = ref.watch(serverLocationProvider);

    const verticalSpacing = 12.0;

    final selectedTag = selected.serverName;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.userPro) ...[
            ProBanner(topMargin: 0),
            const SizedBox(height: verticalSpacing),
          ],
          Flexible(
            child: availableServers.when(
              data: (data) {
                final allLocations = data.lanternServerLocations;
                if (allLocations.isEmpty) {
                  return const Center(child: Text("No locations available"));
                }

                final sections = [
                  _sectionHeader('pro_locations'.i18n),
                  _sectionCard(_locationTiles(allLocations, selectedTag)),
                ];

                return Stack(
                  children: [
                    ScrollConfiguration(
                      behavior: ScrollConfiguration.of(
                        context,
                      ).copyWith(scrollbars: false),
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: sections,
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
                );
              },
              loading: () => const Center(child: Spinner()),
              error: (error, _) => Center(
                child: Text(
                  error.localizedDescription,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0, left: defaultSize),
      child: HeaderText(text),
    );
  }

  Widget _sectionCard(List<Widget> tiles) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _withDividers(tiles),
      ),
    );
  }

  List<Widget> _locationTiles(List<Server> locations, String selectedTag) {
    final grouped = _groupLocationsByCountry(locations);
    final countryEntries = grouped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return countryEntries.map((entry) {
      final country = entry.key;
      final countryLocations = entry.value;

      if (countryLocations.length == 1) {
        final serverData = countryLocations.first;
        return SingleCityServerView(
          key: ValueKey(serverData.tag),
          onServerSelected: onServerSelected,
          server: serverData,
          isSelected: selectedTag == serverData.tag,
        );
      }

      return _CountryCityListView(
        country: country,
        locations: countryLocations,
        selectedServerTag: selectedTag,
        onServerSelected: onServerSelected,
      );
    }).toList();
  }

  List<Widget> _withDividers(List<Widget> tiles) {
    final children = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      children.add(tiles[i]);
      if (i < tiles.length - 1) {
        children.add(const DividerSpace());
      }
    }
    return children;
  }

  Future<void> onServerSelected(Server selectedServer) async {
    if (PlatformUtils.isMacOS) {
      /// Check for if extension permission is granted before connecting to server, if not show the permission dialog first
      final macosExtensionStatus = ref.read(macosExtensionProvider);
      if (!macosExtensionStatus.isReady) {
        appRouter.push(const MacOSExtensionDialog());
        return;
      }
    }

    await _connectToServer(selectedServer);
  }

  Future<void> _connectToServer(Server selectedServer) async {
    final result = await ref
        .read(vpnProvider.notifier)
        .connectToServer(
          ServerLocationType.lanternLocation,
          selectedServer.tag,
        );

    result.fold(
      (failure) {
        if (failure is VpnConflictFailure) {
          AppDialog.vpnConflictDialog(
            context: context,
            onConnectAnyway: () async {
              appRouter.maybePop();
              final retryResult = await ref
                  .read(vpnProvider.notifier)
                  .connectToServer(
                    ServerLocationType.lanternLocation,
                    selectedServer.tag,
                    skipConflictCheck: true,
                  );
              retryResult.fold(
                (failure) =>
                    context.showSnackBar(failure.localizedErrorMessage),
                (_) {
                  ref
                      .read(serverLocationProvider.notifier)
                      .updateServerLocation(
                        ServerLocation.fromServer(server: selectedServer),
                      );
                  appRouter.popUntilRoot();
                },
              );
            },
          );
        } else {
          context.showSnackBar(failure.localizedErrorMessage);
        }
      },
      (_) async {
        final vpnStatus = ref.read(vpnProvider);

        void syncAndPop() {
          ref
              .read(serverLocationProvider.notifier)
              .updateServerLocation(
                ServerLocation.fromServer(server: selectedServer),
              );
          appRouter.popUntilRoot();
        }

        if (vpnStatus == VPNStatus.connected) {
          syncAndPop();
          return;
        }

        ref.listenManual<AsyncValue<LanternStatus>>(vPNStatusProvider, (
          previous,
          next,
        ) {
          if (next is AsyncData<LanternStatus> &&
              next.value.status == VPNStatus.connected) {
            syncAndPop();
          }
        });
      },
    );
  }
}

class _CountryCityListView extends StatefulWidget {
  final String country;
  final List<Server> locations;
  final String selectedServerTag;
  final OnServerSelected onServerSelected;

  const _CountryCityListView({
    required this.country,
    required this.locations,
    required this.selectedServerTag,
    required this.onServerSelected,
  });

  @override
  State<_CountryCityListView> createState() => _CountryCityListViewState();
}

class _CountryCityListViewState extends State<_CountryCityListView> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final countryCode = widget.locations.first.location.countryCode;
    final country = widget.locations.first.location.country;

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
            country,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge!.copyWith(color: context.textPrimary),
          ),
          onExpansionChanged: (expanded) {
            setState(() => _isExpanded = expanded);
          },
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LatencyIndicator(status: LatencyStatus.best(widget.locations)),
              const SizedBox(width: 8),
              ExpansionChevron(isExpanded: _isExpanded),
            ],
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
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LatencyIndicator(status: LatencyStatus.of(server)),
                  const SizedBox(width: 8),
                  const ChevronPlaceholder(),
                ],
              ),
              onPressed: () => _onLocationSelected(context, server),
            );
          }).toList(),
        ),
      );
    }

    return AppTile(
      icon: Flag(countryCode: countryCode),
      label: widget.country,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LatencyIndicator(status: LatencyStatus.best(widget.locations)),
          const SizedBox(width: 8),
          AppImage(
            path: AppImagePaths.arrowForward,
            height: 20.0,
            color: context.textPrimary,
          ),
        ],
      ),
      onPressed: () => _showCountryBottomSheet(context),
    );
  }

  void _onLocationSelected(BuildContext context, Server server) {
    widget.onServerSelected(server);
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
  final OnServerSelected onServerSelected;

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
    final hasPersonalProxies = ref.watch(
      helpersProvider.select((s) => s.view.helpers.isNotEmpty),
    );

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
    context.showLoadingDialog();
    void selected() {
      context.hideLoadingDialog();
      if (connectedMessage != null) context.showSnackBar(connectedMessage);
      ref.read(serverLocationProvider.notifier).updateServerLocation(location);
      appRouter.popUntilRoot();
    }

    final result = await ref
        .read(vpnProvider.notifier)
        .connectToServer(type, tag);
    if (!mounted) return;
    result.fold((failure) {
      context.hideLoadingDialog();
      if (failure is! VpnConflictFailure) {
        context.showSnackBar(failure.localizedErrorMessage);
        return;
      }
      AppDialog.vpnConflictDialog(
        context: context,
        onConnectAnyway: () async {
          appRouter.maybePop();
          final retry = await ref
              .read(vpnProvider.notifier)
              .connectToServer(type, tag, skipConflictCheck: true);
          if (!mounted) return;
          retry.fold((failure) {
            context.hideLoadingDialog();
            context.showSnackBar(failure.localizedErrorMessage);
          }, (_) => selected());
        },
      );
    }, (_) => selected());
  }
}

Map<String, List<Server>> _groupLocationsByCountry(List<Server> servers) {
  final Map<String, List<Server>> result = {};
  for (final server in servers) {
    result.putIfAbsent(server.location.country, () => <Server>[]).add(server);
  }
  return result;
}
