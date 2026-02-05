// lib/features/vpn/server_selection.dart
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/core/models/private_server.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/core/widgets/app_text.dart';
import 'package:lantern/core/widgets/expansion_chevron.dart';
import 'package:lantern/core/widgets/spinner.dart';
import 'package:lantern/features/vpn/provider/available_servers_notifier.dart';
import 'package:lantern/features/vpn/provider/private_servers_provider.dart';
import 'package:lantern/features/vpn/provider/selected_server_location_provider.dart';
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
    final selected = ref.watch(selectedServerLocationProvider);
    final privateServers = ref.watch(privateServersProvider);
    final isUserPro = ref.watch(isUserProProvider);

    _textTheme = Theme.of(context).textTheme;

    // We want both: selected server + private servers list (from Go).
    if (selected.isLoading || privateServers.isLoading) {
      return BaseScreen(
        title: '',
        appBar: CustomAppBar(
          title: Text('server_selection'.i18n),
          actions: [
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: onOpenMoreOptions,
            ),
          ],
        ),
        body: const Center(child: Spinner()),
      );
    }

    final selectedErr = selected.asError;
    final privateErr = privateServers.asError;
    if (selectedErr != null || privateErr != null) {
      final msg = (selectedErr?.error ?? privateErr?.error).toString();
      return BaseScreen(
        title: '',
        appBar: CustomAppBar(
          title: Text('server_selection'.i18n),
          actions: [
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: onOpenMoreOptions,
            ),
          ],
        ),
        body: Center(
          child: Text(
            msg,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final selectedServer = selected.requireValue;
    final servers = privateServers.requireValue;
    final isPrivateServerFound = servers.isNotEmpty;

    return BaseScreen(
      title: '',
      appBar: CustomAppBar(
        title: Text('server_selection'.i18n),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: onOpenMoreOptions,
          ),
        ],
      ),
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
              splashBorderRadius: BorderRadius.circular(40),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.teal.shade900,
              indicatorColor: Colors.transparent,
              dividerHeight: 0,
              padding: EdgeInsets.zero,
              unselectedLabelColor: Colors.grey,
              labelStyle: _textTheme!.titleSmall,
              labelPadding: EdgeInsets.zero,
              indicatorPadding: const EdgeInsets.symmetric(horizontal: size24),
              indicator: BoxDecoration(
                color: AppColors.blue2,
                borderRadius: BorderRadius.circular(40),
                shape: BoxShape.rectangle,
                border: Border.all(color: AppColors.blue3, width: 1),
              ),
              tabs: [
                Tab(child: Text('lantern_servers'.i18n)),
                Tab(child: Text('private_servers'.i18n)),
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

  Widget _buildSmartLocation(ServerLocation selectedServer) {
    // Adjust these if your ServerLocation differs.
    final displayName = (selectedServer.displayName?.isNotEmpty ?? false)
        ? selectedServer.displayName!
        : 'smart_location'.i18n;

    final flag = selectedServer.countryCode ?? '';
    final protocol = selectedServer.protocol ?? '';

    final serverType = selectedServer.serverType?.toString();
    final isAutoSelected = serverType == ServerLocationType.auto.name ||
        serverType == ServerLocationType.auto.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'smart_location'.i18n,
            style: _textTheme?.labelLarge!.copyWith(color: AppColors.gray8),
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: AppTile(
            icon:
                flag.isEmpty ? AppImagePaths.location : Flag(countryCode: flag),
            label: displayName.i18n,
            onPressed: onSmartLocation,
            subtitle: protocol.isEmpty
                ? null
                : Text(
                    protocol.capitalize,
                    style: _textTheme!.labelMedium!.copyWith(
                      color: AppColors.gray7,
                    ),
                  ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isAutoSelected) AppImage(path: AppImagePaths.blot),
              ],
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
      (_) async {
        // Source of truth is Go.
        await ref.read(selectedServerLocationProvider.notifier).refreshFromGo();
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
              label: 'setup_private_server'.i18n,
              onPressed: () {
                context.pushRoute(PrivateServerSetup());
              },
            ),
            const DividerSpace(padding: EdgeInsets.zero),
            AppTile(
              label: 'join_a_private_server'.i18n,
              onPressed: () {
                context.pushRoute(JoinPrivateServer());
              },
            ),
            const DividerSpace(padding: EdgeInsets.zero),
            AppTile(
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
    final selected = ref.watch(selectedServerLocationProvider);

    const verticalSpacing = 12.0;

    final selectedTag = selected.maybeWhen(
      data: (s) => (s.serverName).toString(),
      orElse: () => '',
    );

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
                        behavior: ScrollConfiguration.of(context)
                            .copyWith(scrollbars: false),
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
                            color: AppColors.white.withValues(alpha: 0.72),
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
    final result = await ref.read(vpnProvider.notifier).connectToServer(
          ServerLocationType.lanternLocation,
          selectedServer.tag,
        );

    result.fold(
      (failure) => context.showSnackBar(failure.localizedErrorMessage),
      (_) async {
        final vpnStatus = ref.read(vpnProvider);

        Future<void> syncAndPop() async {
          await ref
              .read(selectedServerLocationProvider.notifier)
              .refreshFromGo();
          appRouter.popUntilRoot();
        }

        if (vpnStatus == VPNStatus.connected) {
          await syncAndPop();
          return;
        }

        ref.listenManual<AsyncValue<LanternStatus>>(
          vPNStatusProvider,
          (previous, next) async {
            if (next is AsyncData<LanternStatus> &&
                next.value.status == VPNStatus.connected) {
              await syncAndPop();
            }
          },
        );
      },
    );
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
    super.key,
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
          childrenPadding:
              const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
          leading: Flag(countryCode: countryCode),
          title: Text(
            country,
            style: Theme.of(context)
                .textTheme
                .bodyLarge!
                .copyWith(color: AppColors.gray9),
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
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium!
                          .copyWith(color: AppColors.gray7),
                    ),
              tileTextStyle: Theme.of(context)
                  .textTheme
                  .bodyMedium!
                  .copyWith(color: AppColors.gray9),
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
        color: AppColors.gray9,
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

    final privateServers = ref.watch(privateServersProvider);
    final selected = ref.watch(selectedServerLocationProvider);

    if (privateServers.isLoading || selected.isLoading) {
      return const Center(child: Spinner());
    }

    final err = privateServers.asError ?? selected.asError;
    if (err != null) {
      return Center(
        child: Text(
          err.error.toString(),
          textAlign: TextAlign.center,
        ),
      );
    }

    final servers = privateServers.requireValue;
    final selectedServer = selected.requireValue;

    final selectedPrivateName = (selectedServer.serverName ?? '').toString();

    // NOTE: adjust these filters if your PrivateServer model differs.
    // Common patterns: `joined` boolean, or `isJoined`.
    final myServer = servers.where((s) => (s.isJoined) == false).toList();
    final joinedServer = servers.where((s) => (s.isJoined) == true).toList();

    if (servers.isEmpty) {
      return Column(
        children: [
          Text(
            'no_private_server_setup_yet'.i18n,
            textAlign: TextAlign.center,
            style: _textTheme!.titleSmall!.copyWith(color: AppColors.gray8),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'setup_private_server'.i18n,
            onPressed: () {
              context.pushRoute(VPNSetting());
            },
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
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
            itemCount: myServer.length,
            separatorBuilder: (_, __) => const DividerSpace(),
            itemBuilder: (context, index) {
              final server = myServer[index];

              final serverName = server.serverName ?? '';
              final countryCode = server.serverCountryCode ?? '';
              final locationName =
                  server.serverLocationName?.locationName ?? '';
              final externalIp = server.externalIp ?? '';
              final protocol = server.protocol ?? '';

              return AppTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                onPressed: () {
                  if (selectedPrivateName == serverName) {
                    appLogger.debug('Already selected this server');
                    context.showSnackBar('server_already_selected'.i18n);
                    return;
                  }
                  onPrivateServerSelected(server);
                },
                icon: Flag(
                  countryCode: countryCode,
                  size: const Size(40, 28),
                ),
                label: serverName,
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                        '$locationName - $externalIp',
                        style: _textTheme!.labelMedium!.copyWith(
                          color: AppColors.gray7,
                        ),
                      ),
                    ),
                    if (protocol.isNotEmpty)
                      Text(
                        protocol.capitalize,
                        style: _textTheme!.labelMedium!.copyWith(
                          color: AppColors.gray7,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        if (joinedServer.isNotEmpty) ...{
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: HeaderText('joined_servers'.i18n),
          ),
          const SizedBox(height: 8),
          AppCard(
            padding: EdgeInsets.zero,
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: joinedServer.map((server) {
                final serverName = server.serverName ?? '';
                final countryCode = server.serverCountryCode ?? '';
                final locationName =
                    server.serverLocationName?.locationName ?? '';
                final externalIp = server.externalIp ?? '';

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppTile(
                      onPressed: () {
                        onPrivateServerSelected(server);
                      },
                      icon: Flag(
                        countryCode: countryCode,
                        size: const Size(40, 28),
                      ),
                      label: serverName,
                      subtitle: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          '$locationName - $externalIp',
                          style: _textTheme!.labelMedium!.copyWith(
                            color: AppColors.gray7,
                          ),
                        ),
                      ),
                    ),
                    const DividerSpace(padding: EdgeInsets.zero),
                  ],
                );
              }).toList(),
            ),
          ),
        },
      ],
    );
  }

  Future<void> onPrivateServerSelected(PrivateServer privateServer) async {
    context.showLoadingDialog();

    final serverName = (privateServer.serverName ?? '').trim();

    final result = await ref.read(vpnProvider.notifier).connectToServer(
          ServerLocationType.privateServer,
          serverName,
        );

    result.fold(
      (failure) {
        context.hideLoadingDialog();
        context.showSnackBar(failure.localizedErrorMessage);
      },
      (_) async {
        context.hideLoadingDialog();
        context.showSnackBar('connected_to_private_server'.i18n);

        // Source of truth is Go.
        await ref.read(selectedServerLocationProvider.notifier).refreshFromGo();
        appRouter.popUntilRoot();
      },
    );
  }
}

Map<String, List<Location_>> _groupLocationsByCountry(
    List<Location_> locations) {
  final Map<String, List<Location_>> result = {};
  for (final loc in locations) {
    result.putIfAbsent(loc.country, () => <Location_>[]).add(loc);
  }
  return result;
}
