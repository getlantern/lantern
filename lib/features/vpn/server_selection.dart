import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/core/widgets/app_text.dart';
import 'package:lantern/core/widgets/expansion_chevron.dart';
import 'package:lantern/core/widgets/spinner.dart';
import 'package:lantern/features/macos_extension/provider/macos_extension_notifier.dart';
import 'package:lantern/features/vpn/provider/available_servers_notifier.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_status_notifier.dart';
import 'package:lantern/features/vpn/single_city_server_view.dart';

typedef OnServerSelected = Function(Location_ selectedServer);

@RoutePage(name: 'ServerSelection')
class ServerSelection extends StatefulHookConsumerWidget {
  const ServerSelection({super.key});

  @override
  ConsumerState<ServerSelection> createState() => _ServerSelectionState();
}

class _ServerSelectionState extends ConsumerState<ServerSelection> {
  TextTheme? _textTheme;

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(serverLocationProvider);
    final availableServers = ref.watch(availableServersProvider);
    final isUserPro = ref.watch(isUserProProvider);

    _textTheme = Theme.of(context).textTheme;

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
    final isPrivateServerFound =
        availableServers.requireValue.user.outbounds.isNotEmpty;

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
                    'automatically_chooses_fastest_location'.i18n,
                    style: _textTheme?.bodyMedium!.copyWith(
                      color: AppColors.gray8,
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
              'automatically_chooses_fastest_location'.i18n,
              style: _textTheme?.bodyMedium!.copyWith(color: AppColors.gray8),
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
                  child: Text('private_servers'.i18n),
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
    final displayName = autoLocation?.displayName ?? 'smart_location'.i18n;
    final flag = autoLocation?.countryCode ?? '';
    final protocol = autoLocation?.protocol ?? '';
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
            trailing: AppImage(
              path: AppImagePaths.blot,
              color: context.statusWarningBgDot,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> onSmartLocation() async {
    final result = await ref.read(vpnProvider.notifier).startVPN(force: true);

    result.fold(
      (failure) => context.showSnackBar(failure.localizedErrorMessage),
      (_) {
        appRouter.popUntilRoot();
      },
    );
  }

  void onOpenMoreOptions() {
    showAppBottomSheet(
      context: context,
      title: 'private_server_options'.i18n,
      scrollControlDisabledMaxHeightRatio: .4,
      builder: (context, scrollController) {
        return ListView(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          children: [
            AppTile(
              tileKey: const Key('server_selection.setup_private_server'),
              label: 'setup_private_server'.i18n,
              onPressed: () {
                context.pushRoute(PrivateServerSetup());
              },
            ),
            const DividerSpace(padding: EdgeInsets.zero),
            AppTile(
              tileKey: const Key('server_selection.join_private_server'),
              label: 'join_a_private_server'.i18n,
              onPressed: () {
                context.pushRoute(JoinPrivateServer());
              },
            ),
            const DividerSpace(padding: EdgeInsets.zero),
            AppTile(
              tileKey: const Key('server_selection.manage_private_servers'),
              label: 'manage_private_servers'.i18n,
              onPressed: () {
                context.pushRoute(ManagePrivateServer());
              },
            ),
          ],
        );
      },
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
          Padding(
            padding: const EdgeInsets.only(top: 4.0, left: defaultSize),
            child: HeaderText('pro_locations'.i18n),
          ),
          Flexible(
            child: AppCard(
              padding: EdgeInsets.zero,
              child: availableServers.when(
                data: (data) {
                  final locations = data.lantern.locations.values.toList();

                  if (locations.isEmpty) {
                    return const Center(child: Text("No locations available"));
                  }

                  final grouped = _groupLocationsByCountry(locations);
                  final countryEntries = grouped.entries.toList()
                    ..sort((a, b) => a.key.compareTo(b.key));

                  return Stack(
                    children: [
                      ScrollConfiguration(
                        behavior: ScrollConfiguration.of(
                          context,
                        ).copyWith(scrollbars: false),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: countryEntries.length,
                          separatorBuilder: (_, __) => const DividerSpace(),
                          itemBuilder: (context, index) {
                            final entry = countryEntries[index];
                            final country = entry.key;
                            final countryLocations = entry.value;

                            if (countryLocations.length == 1) {
                              final serverData = countryLocations.first;
                              return SingleCityServerView(
                                key: ValueKey(serverData.tag),
                                onServerSelected: onServerSelected,
                                location: serverData,
                                isSelected: selectedTag == serverData.tag,
                              );
                            }

                            return _CountryCityListView(
                              country: country,
                              locations: countryLocations,
                              selectedServerTag: selectedTag,
                              onServerSelected: onServerSelected,
                            );
                          },
                        ),
                      ),
                      if (!widget.userPro)
                        Positioned.fill(
                          child: Container(
                            color: context.bgElevated.withValues(alpha: 0.72),
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
          ),
        ],
      ),
    );
  }

  Future<void> onServerSelected(Location_ selectedServer) async {
    if (PlatformUtils.isMacOS) {
      /// Check for if extension permission is granted before connecting to server, if not show the permission dialog first
      final macosExtensionStatus = ref.read(macosExtensionProvider);
      if (!macosExtensionStatus.isReady) {
        appRouter.push(const MacOSExtensionDialog());
        return;
      }
    }

    final result = await ref
        .read(vpnProvider.notifier)
        .connectToServer(
          ServerLocationType.lanternLocation,
          selectedServer.tag,
        );

    result.fold((failure) {
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
              (failure) => context.showSnackBar(failure.localizedErrorMessage),
              (_) => _onLanternServerConnected(ref, selectedServer),
            );
          },
        );
      } else {
        context.showSnackBar(failure.localizedErrorMessage);
      }
    }, (_) => _onLanternServerConnected(ref, selectedServer));
  }

  void _onLanternServerConnected(WidgetRef ref, Location_ selectedServer) {
    final vpnStatus = ref.read(vpnProvider);

    Future<void> syncAndPop() async {
      await ref
          .read(serverLocationProvider.notifier)
          .updateServerLocation(
            ServerLocation.fromLanternLocation(server: selectedServer),
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
    ) async {
      if (next is AsyncData<LanternStatus> &&
          next.value.status == VPNStatus.connected) {
        await syncAndPop();
      }
    });
  }
}

class _CountryCityListView extends StatefulWidget {
  final String country;
  final List<Location_> locations;
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
    final countryCode = widget.locations.first.countryCode;
    final country = widget.locations.first.country;

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
          trailing: ExpansionChevron(isExpanded: _isExpanded),
          shape: const RoundedRectangleBorder(side: BorderSide.none),
          children: widget.locations.map((loc) {
            return AppTile(
              dense: true,
              minHeight: 58,
              contentPadding: const EdgeInsets.only(left: 53, right: 14),
              label: loc.city,
              subtitle: loc.protocol.isEmpty
                  ? null
                  : Text(
                      loc.protocol.capitalize,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelMedium!.copyWith(
                        color: context.textSecondary,
                      ),
                    ),
              tileTextStyle: Theme.of(
                context,
              ).textTheme.bodyMedium!.copyWith(color: context.textPrimary),
              onPressed: () => _onLocationSelected(context, loc),
            );
          }).toList(),
        ),
      );
    }

    return AppTile(
      icon: Flag(countryCode: countryCode),
      label: widget.country,
      trailing: AppImage(
        path: AppImagePaths.arrowForward,
        height: 20.0,
        color: context.textPrimary,
      ),
      onPressed: () => _showCountryBottomSheet(context),
    );
  }

  void _onLocationSelected(BuildContext context, Location_ location) {
    widget.onServerSelected(location);
  }

  void _showCountryBottomSheet(BuildContext context) {
    showAppBottomSheet(
      context: context,
      title: widget.country,
      scrollControlDisabledMaxHeightRatio: 0.45,
      builder: (bottomSheetContext, scrollController) {
        return Flexible(
          child: ListView.separated(
            controller: scrollController,
            padding: EdgeInsets.zero,
            itemCount: widget.locations.length,
            separatorBuilder: (_, __) =>
                const DividerSpace(padding: EdgeInsets.zero),
            itemBuilder: (_, index) {
              final loc = widget.locations[index];
              final isSelected = widget.selectedServerTag == loc.tag;

              return SingleCityServerView(
                nested: true,
                onServerSelected: (selected) {
                  Navigator.of(bottomSheetContext).pop();
                  widget.onServerSelected(selected);
                },
                location: loc,
                isSelected: isSelected,
              );
            },
          ),
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

    final userLocations = availableServers.requireValue.user.locations.values
        .toList();

    final selectedTag = selected.serverName;

    if (userLocations.isEmpty) {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: HeaderText('your_server'.i18n),
        ),
        const SizedBox(height: 8),
        AppCard(
          padding: EdgeInsets.zero,
          child: ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: userLocations.length,
            separatorBuilder: (_, __) => const DividerSpace(),
            itemBuilder: (context, index) {
              final loc = userLocations[index];
              final isSelected = selectedTag == loc.tag;
              return AppTile(
                tileKey: Key('server_selection.private_server.${loc.tag}'),
                onPressed: () {
                  if (isSelected) {
                    appLogger.debug('Already selected this server');
                    context.showSnackBar('server_already_selected'.i18n);
                    return;
                  }
                  onPrivateServerSelected(loc);
                },
                icon: Flag(
                  countryCode: loc.countryCode,
                  size: const Size(40, 28),
                ),
                label: loc.tag,
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                        '${loc.city} - ${loc.protocol}',
                        style: _textTheme!.labelMedium!.copyWith(
                          color: context.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
                trailing: isSelected
                    ? AppImage(path: AppImagePaths.blot)
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> onPrivateServerSelected(Location_ location) async {
    context.showLoadingDialog();

    final result = await ref
        .read(vpnProvider.notifier)
        .connectToServer(ServerLocationType.privateServer, location.tag);

    result.fold((failure) {
      context.hideLoadingDialog();
      if (failure is VpnConflictFailure) {
        AppDialog.vpnConflictDialog(
          context: context,
          onConnectAnyway: () async {
            appRouter.maybePop();
            final retryResult = await ref
                .read(vpnProvider.notifier)
                .connectToServer(
                  ServerLocationType.privateServer,
                  location.tag,
                  skipConflictCheck: true,
                );
            retryResult.fold((failure) {
              context.hideLoadingDialog();
              context.showSnackBar(failure.localizedErrorMessage);
            }, (_) => _onPrivateServerConnected(ref, location));
          },
        );
      } else {
        context.showSnackBar(failure.localizedErrorMessage);
      }
    }, (_) => _onPrivateServerConnected(ref, location));
  }

  void _onPrivateServerConnected(WidgetRef ref, Location_ location) async {
    context.hideLoadingDialog();
    context.showSnackBar('connected_to_private_server'.i18n);

    await ref
        .read(serverLocationProvider.notifier)
        .updateServerLocation(
          ServerLocation(
            serverType: ServerLocationType.privateServer.name,
            serverName: location.tag,
            country: location.country,
            city: location.city,
            countryCode: location.countryCode,
            protocol: location.protocol,
          ),
        );
    appRouter.popUntilRoot();
  }
}

Map<String, List<Location_>> _groupLocationsByCountry(
  List<Location_> locations,
) {
  final Map<String, List<Location_>> result = {};
  for (final loc in locations) {
    result.putIfAbsent(loc.country, () => <Location_>[]).add(loc);
  }
  return result;
}
