import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/models/entity/private_server_entity.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/widgets/app_text.dart';
import 'package:lantern/core/widgets/expansion_chevron.dart';
import 'package:lantern/core/widgets/spinner.dart';
import 'package:lantern/features/vpn/provider/available_servers_notifier.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_status_notifier.dart';
import 'package:lantern/features/vpn/server_mobile_view.dart';

import '../../core/models/entity/server_location_entity.dart'
    show ServerLocationEntity;

typedef OnServerSelected = Function(Location_ selectedServer);

@RoutePage(name: 'ServerSelection')
class ServerSelection extends StatefulHookConsumerWidget {
  const ServerSelection({super.key});

  @override
  ConsumerState<ServerSelection> createState() => _ServerSelectionState();
}

class _ServerSelectionState extends ConsumerState<ServerSelection> {
  TextTheme? _textTheme;
  final storage = sl<LocalStorageService>();

  @override
  Widget build(BuildContext context) {
    var serverLocation = ref.watch(serverLocationProvider);
    final isUserPro = ref.watch(isUserProProvider);
    _textTheme = Theme.of(context).textTheme;
    final isPrivateServerFound = storage.getPrivateServer().isNotEmpty;
    return BaseScreen(
      title: '',
      appBar: CustomAppBar(
        title: Text('server_selection'.i18n),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: onOpenMoreOptions,
          ),
        ],
      ),
      body: isPrivateServerFound
          ? _buildBody(serverLocation, isUserPro)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSelectedLocation(serverLocation),
                _buildSmartLocation(serverLocation),
                SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text('automatically_chooses_fastest_location'.i18n,
                      style: _textTheme?.bodyMedium!.copyWith(
                        color: AppColors.gray8,
                      )),
                ),
                SizedBox(height: size24),
                Flexible(child: ServerLocationListView(userPro: isUserPro)),
              ],
            ),
    );
  }

  Widget _buildBody(ServerLocationEntity serverLocation, bool isUserPro) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildSelectedLocation(serverLocation),
          _buildSmartLocation(serverLocation),
          SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('automatically_chooses_fastest_location'.i18n,
                style: _textTheme?.bodyMedium!.copyWith(
                  color: AppColors.gray8,
                )),
          ),
          SizedBox(height: size24),
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
              indicatorPadding: EdgeInsets.symmetric(horizontal: size24),
              indicator: BoxDecoration(
                color: AppColors.blue2,
                borderRadius: BorderRadius.circular(40),
                shape: BoxShape.rectangle,
                border: Border.all(color: AppColors.blue3, width: 1),
              ),
              tabs: [
                Tab(child: Text('lantern_servers'.i18n)),
                Tab(child: Text('private_servers'.i18n))
              ],
            ),
          ),
          SizedBox(height: 8),
          DividerSpace(padding: EdgeInsets.zero),
          SizedBox(height: defaultSize),
          Expanded(
            child: TabBarView(
              children: [
                ServerLocationListView(userPro: isUserPro),
                PrivateServerLocationListView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartLocation(ServerLocationEntity serverLocation) {
    final autoLocation = serverLocation.autoLocation;
    final displayName = autoLocation?.displayName ?? 'smart_location'.i18n;
    final flag = autoLocation?.countryCode ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'smart_location'.i18n,
            style: _textTheme?.labelLarge!.copyWith(
              color: AppColors.gray8,
            ),
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: AppTile(
            icon:
                flag.isEmpty ? AppImagePaths.location : Flag(countryCode: flag),
            label: displayName.i18n,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppImage(path: AppImagePaths.blot),
                AppRadioButton<bool>(
                  value: true,
                  groupValue: serverLocation.serverType.toServerLocationType ==
                      ServerLocationType.auto,
                  onChanged: (value) =>
                      onSmartLocation(ServerLocationType.auto),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedLocation(ServerLocationEntity serverLocation) {
    if (serverLocation.serverType.toServerLocationType ==
        ServerLocationType.auto) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text('selected_location'.i18n,
              style: _textTheme?.labelLarge!.copyWith(
                color: AppColors.gray8,
              )),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: AppTile(
            icon: Flag(countryCode: serverLocation.countryCode),
            label: getServerName(serverLocation),
            subtitle: getServerLocation(serverLocation),
            trailing: AppRadioButton<String>(
              value: serverLocation.serverName,
              groupValue: serverLocation.serverName,
              onChanged: (value) {},
            ),
          ),
        ),
        SizedBox(height: defaultSize),
      ],
    );
  }

  String getServerName(ServerLocationEntity serverLocation) {
    switch (serverLocation.serverType.toServerLocationType) {
      case ServerLocationType.lanternLocation:
        return serverLocation.displayName.split('[')[0].trim();
      case ServerLocationType.privateServer:
        return serverLocation.serverName;
      case ServerLocationType.auto:
        return 'Smart Location';
    }
  }

  Widget? getServerLocation(ServerLocationEntity serverLocation) {
    switch (serverLocation.serverType.toServerLocationType) {
      case ServerLocationType.lanternLocation:
      case ServerLocationType.auto:
        return null; // No additional location info for these types
      case ServerLocationType.privateServer:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Text(
            serverLocation.displayName,
            style: _textTheme!.labelMedium!.copyWith(
              color: AppColors.gray7,
            ),
          ),
        );
    }
  }

  String getServerCountryCode(ServerLocationEntity serverLocation) {
    switch (serverLocation.serverType.toServerLocationType) {
      case ServerLocationType.lanternLocation:
        return serverLocation.countryCode;
      case ServerLocationType.privateServer:
        return serverLocation.countryCode;
      case ServerLocationType.auto:
        return 'Smart Location';
    }
  }

  Future<void> onSmartLocation(ServerLocationType type) async {
    final result = await ref.read(vpnProvider.notifier).startVPN(force: true);
    result.fold(
      (failure) {
        context.showSnackBar(failure.localizedErrorMessage);
      },
      (success) async {
        final auto = ref.read(serverLocationProvider);
        final autoCountry = auto.country;
        final autoCity = auto.city;
        final serverLocation = ServerLocationEntity(
          serverType: type.name,
          serverName: 'Smart Location',
          autoSelect: true,
          displayName: '$autoCountry - $autoCity',
          city: autoCity,
          country: autoCountry,
          countryCode: auto.countryCode,
        );
        await ref
            .read(serverLocationProvider.notifier)
            .updateServerLocation(serverLocation);

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
            DividerSpace(padding: EdgeInsets.zero),
            AppTile(
              label: 'join_a_private_server'.i18n,
              onPressed: () {
                context.pushRoute(JoinPrivateServer());
              },
            ),
            DividerSpace(padding: EdgeInsets.zero),
            if (storage.getPrivateServer().isNotEmpty)
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

  const ServerLocationListView({
    super.key,
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
    final availableServers = ref.watch(availableServersProvider);
    final serverLocation = ref.watch(serverLocationProvider);
    const verticalSpacing = 12.0;

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

                  // Group by country
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
                          separatorBuilder: (_, __) => const DividerSpace(
                            padding: EdgeInsets.zero,
                          ),
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
                                isSelected:
                                    serverLocation.serverName == serverData.tag,
                              );
                            }

                            ///Multiple cities in the same country
                            return _CountryCityListView(
                              country: country,
                              locations: countryLocations,
                              selectedServerTag: serverLocation.serverName,
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
                error: (error, stackTrace) => Center(
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
        ServerLocationType.lanternLocation, selectedServer.tag);

    result.fold(
      (failure) {
        context.showSnackBar(failure.localizedErrorMessage);
      },
      (success) async {
        final vpnStatus = ref.read(vpnProvider);
        if (vpnStatus == VPNStatus.connected) {
          ///User is already connected, just update the server location
          final savedServerLocation =
              sl<LocalStorageService>().getSavedServerLocations();
          final serverLocation = savedServerLocation.lanternLocation(
            server: selectedServer,
            autoSelect: false,
          );
          await ref
              .read(serverLocationProvider.notifier)
              .updateServerLocation(serverLocation);
          appRouter.popUntilRoot();
          return;
        }

        ref.listenManual<AsyncValue<LanternStatus>>(
          vPNStatusProvider,
          (previous, next) async {
            if (next is AsyncData<LanternStatus> &&
                next.value.status == VPNStatus.connected) {
              final savedServerLocation =
                  sl<LocalStorageService>().getSavedServerLocations();
              final serverLocation = savedServerLocation.lanternLocation(
                server: selectedServer,
                autoSelect: false,
              );
              await ref
                  .read(serverLocationProvider.notifier)
                  .updateServerLocation(serverLocation);

              appRouter.popUntilRoot();
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
    final textTheme = Theme.of(context).textTheme;
    if (PlatformUtils.isDesktop) {
      return Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          enableFeedback: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
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
            final isSelected = widget.selectedServerTag == loc.tag;
            return AppTile(
              dense: true,
              minHeight: 58,
              contentPadding: const EdgeInsets.only(left: 53, right: 14),
              label: loc.city,
              subtitle:loc.protocol.isEmpty?null: Text(
                loc.protocol.capitalize,
                maxLines: 1,
                style: Theme.of(context).textTheme.labelMedium!.copyWith(
                      color: AppColors.gray7,
                    ),
              ),
              tileTextStyle: Theme.of(context)
                  .textTheme
                  .bodyMedium!
                  .copyWith(color: AppColors.gray9),
              trailing: AppRadioButton<String>(
                value: loc.tag,
                groupValue: isSelected ? loc.tag : null,
                onChanged: (_) => _onLocationSelected(context, loc),
              ),
              onPressed: () => _onLocationSelected(context, loc),
            );
          }).toList(),
        ),
      );
    }

    final location = widget.locations.first;
    return AppTile(
      icon: Flag(countryCode: countryCode),
      label: widget.country,
      subtitle: widget.locations.first.protocol.isEmpty
          ? null
          : Text(
              location.protocol.capitalize,
              style: textTheme.labelMedium!.copyWith(
                color: AppColors.gray7,
              ),
            ),
      trailing: Icon(
        Icons.keyboard_arrow_down_rounded,
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
  final _localStorage = sl<LocalStorageService>();
  TextTheme? _textTheme;

  @override
  Widget build(BuildContext context) {
    _textTheme = Theme.of(context).textTheme;

    final userSelectedServer = ref.watch(serverLocationProvider);
    final servers = _localStorage.getPrivateServer();
    final myServer = servers.where((element) => !element.isJoined).toList();
    final joinedServer = servers.where((element) => element.isJoined).toList();

    if (servers.isEmpty) {
      return Column(
        children: [
          Text('no_private_server_setup_yet'.i18n,
              textAlign: TextAlign.center,
              style: _textTheme!.titleSmall!.copyWith(
                color: AppColors.gray8,
              )),
          SizedBox(height: 16),
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
        SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: HeaderText('your_server'.i18n),
        ),
        SizedBox(height: 8),
        AppCard(
          padding: EdgeInsets.zero,
          child: ListView(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            children: myServer.map(
              (server) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppTile(
                      onPressed: () {
                        if (userSelectedServer.serverName ==
                            server.serverName) {
                          appLogger.debug('Already selected this server');
                          context.showSnackBar('server_already_selected'.i18n);
                          return;
                        }
                        onPrivateServerSelected(server);
                      },
                      icon: Flag(
                        countryCode: server.serverLocation.countryCode,
                        size: Size(40, 28),
                      ),
                      label: server.serverName,
                      subtitle: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          '${server.serverLocation.locationName} - ${server.externalIp}',
                          style: _textTheme!.labelMedium!.copyWith(
                            color: AppColors.gray7,
                          ),
                        ),
                      ),
                      trailing: AppRadioButton<String>(
                        value: server.serverName,
                        groupValue:
                            (userSelectedServer.serverName == server.serverName)
                                ? server.serverName
                                : null,
                        onChanged: (value) {
                          if (userSelectedServer.serverName ==
                              server.serverName) {
                            appLogger.debug('Already selected this server');
                            context
                                .showSnackBar('server_already_selected'.i18n);
                            return;
                          }
                          onPrivateServerSelected(server);
                        },
                      ),
                    ),
                    DividerSpace(padding: EdgeInsets.zero),
                  ],
                );
              },
            ).toList(),
          ),
        ),
        SizedBox(height: 16),
        if (joinedServer.isNotEmpty) ...{
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: HeaderText('joined_servers'.i18n),
          ),
          SizedBox(height: 8),
          AppCard(
            padding: EdgeInsets.zero,
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: joinedServer.map(
                (server) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppTile(
                        onPressed: () {
                          onPrivateServerSelected(server);
                        },
                        icon: Flag(
                          countryCode: server.serverLocation.countryCode,
                          size: Size(40, 28),
                        ),
                        label: server.serverName,
                        subtitle: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text(
                            '${server.serverLocation.locationName} - ${server.externalIp}',
                            style: _textTheme!.labelMedium!.copyWith(
                              color: AppColors.gray7,
                            ),
                          ),
                        ),
                        trailing: AppRadioButton<String>(
                          value: server.serverName,
                          groupValue: (userSelectedServer.serverName ==
                                  server.serverName)
                              ? server.serverName
                              : null,
                          onChanged: (value) {
                            onPrivateServerSelected(server);
                          },
                        ),
                      ),
                      DividerSpace(padding: EdgeInsets.zero),
                    ],
                  );
                },
              ).toList(),
            ),
          )
        }
      ],
    );
  }

  Future<void> onPrivateServerSelected(
      PrivateServerEntity privateServer) async {
    context.showLoadingDialog();

    ///Save the selected private server location
    final serverLocation = ServerLocationEntity(
      serverType: ServerLocationType.privateServer.name,
      serverName: privateServer.serverName,
      autoSelect: false,
      displayName: privateServer.serverLocationName,
      city: privateServer.serverLocationName,
      countryCode: privateServer.serverCountryCode,
      country: '',
    );

    ref
        .read(serverLocationProvider.notifier)
        .updateServerLocation(serverLocation);

    /// Connect to the private server
    final result = await ref.read(vpnProvider.notifier).connectToServer(
        ServerLocationType.privateServer, privateServer.serverName.trim());

    result.fold(
      (failure) {
        context.hideLoadingDialog();
        context.showSnackBar(failure.localizedErrorMessage);
      },
      (success) {
        context.hideLoadingDialog();
        context.showSnackBar('connected_to_private_server'.i18n);
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
