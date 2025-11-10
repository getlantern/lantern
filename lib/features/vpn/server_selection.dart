import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/models/entity/private_server_entity.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/utils/country_utils.dart';
import 'package:lantern/core/widgets/app_text.dart';
import 'package:lantern/core/widgets/spinner.dart';
import 'package:lantern/features/vpn/provider/available_servers_notifier.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_status_notifier.dart';
import 'package:lantern/features/vpn/server_mobile_view.dart';

import '../../core/models/entity/server_location_entity.dart'
    show ServerLocationEntity;

typedef OnSeverSelected = Function(Location_ selectedServer);

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
    var serverLocation = ref.watch(serverLocationNotifierProvider);
    final isUserPro = ref.isUserPro;
    _textTheme = Theme.of(context).textTheme;
    final isPrivateServerFound = storage.getPrivateServer().isNotEmpty;
    return BaseScreen(
      title: '',
      appBar: CustomAppBar(
        title: Text(
          'server_selection'.i18n,
        ),
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
    final value =
        serverLocation.autoLocation.serverLocation.split('[')[0].trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text('smart_location'.i18n,
              style: _textTheme?.labelLarge!.copyWith(
                color: AppColors.gray8,
              )),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: AppTile(
            icon: serverLocation.autoLocation.serverLocation.countryCode.isEmpty
                ? AppImagePaths.location
                : Flag(countryCode: serverLocation.serverLocation.countryCode),
            label: value,
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
            icon: Flag(countryCode: serverLocation.serverLocation.countryCode),
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
        return serverLocation.serverLocation.split('[')[0].trim();
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
            serverLocation.serverLocation.locationName,
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
        return serverLocation.serverLocation.countryCode;
      case ServerLocationType.privateServer:
        return serverLocation.serverLocation.countryCode;
      case ServerLocationType.auto:
        return 'Smart Location';
    }
  }

  Future<void> onSmartLocation(ServerLocationType type) async {
    final result =
        await ref.read(vpnNotifierProvider.notifier).startVPN(force: true);
    result.fold(
      (failure) {
        context.showSnackBar(failure.localizedErrorMessage);
      },
      (success) async {
        final serverLocation = ServerLocationEntity(
          serverType: type.name,
          serverName: 'Smart Location',
          autoSelect: true,
          serverLocation: ServerLocationType.auto.name,
        );
        await ref
            .read(serverLocationNotifierProvider.notifier)
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
    final availableServers = ref.watch(availableServersNotifierProvider);
    final serverLocation = ref.watch(serverLocationNotifierProvider);
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
              // small top offset
              child: HeaderText('pro_locations'.i18n)),
          Flexible(
            child: AppCard(
              padding: EdgeInsets.zero,
              child: availableServers.when(
                data: (data) {
                  final locations = data.lantern.locations.values.toList();

                  if (locations.isEmpty) {
                    return const Center(child: Text("No locations available"));
                  }
                  return Stack(
                    children: [
                      ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: locations.length,
                        separatorBuilder: (_, __) => const DividerSpace(
                          padding: EdgeInsets.zero,
                        ),
                        itemBuilder: (context, index) {
                          final serverData = locations[index];
                          return ServerMobileView(
                            key: ValueKey(serverData.tag),
                            onServerSelected: onServerSelected,
                            location: serverData,
                            isSelected:
                                serverLocation.serverName == serverData.tag,
                          );
                        },
                      ),
                      if (!widget.userPro)
                        Positioned.fill(
                          child: Container(
                              color: AppColors.white.withValues(alpha: 0.72),
                              alignment: Alignment.center),
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
    final result = await ref.read(vpnNotifierProvider.notifier).connectToServer(
        ServerLocationType.lanternLocation, selectedServer.tag);

    result.fold(
      (failure) {
        context.showSnackBar(failure.localizedErrorMessage);
      },
      (success) async {
        final vpnStatus = ref.read(vpnNotifierProvider);
        if (vpnStatus == VPNStatus.connected) {
          ///User is already connected, just update the server location
          final serverLocation = ServerLocationEntity(
            serverType: ServerLocationType.lanternLocation.name,
            serverName: selectedServer.tag,
            autoSelect: false,
            serverLocation:
                '${selectedServer.city} [${CountryUtils.getCountryCode(selectedServer.country)}]',
          );
          await ref
              .read(serverLocationNotifierProvider.notifier)
              .updateServerLocation(serverLocation);
          appRouter.popUntilRoot();
          return;
        }

        ref.listenManual<AsyncValue<LanternStatus>>(
          vPNStatusNotifierProvider,
          (previous, next) async {
            if (next is AsyncData<LanternStatus> &&
                next.value.status == VPNStatus.connected) {
              final serverLocation = ServerLocationEntity(
                serverType: ServerLocationType.lanternLocation.name,
                serverName: selectedServer.tag,
                autoSelect: false,
                serverLocation:
                    '${selectedServer.city} [${CountryUtils.getCountryCode(selectedServer.country)}]',
              );
              await ref
                  .read(serverLocationNotifierProvider.notifier)
                  .updateServerLocation(serverLocation);
              appRouter.popUntilRoot();
            }
          },
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

    final userSelectedServer = ref.watch(serverLocationNotifierProvider);
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
      serverLocation: privateServer.serverLocationName,
    );

    ref
        .read(serverLocationNotifierProvider.notifier)
        .updateServerLocation(serverLocation);

    /// Connect to the private server
    final result = await ref.read(vpnNotifierProvider.notifier).connectToServer(
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
