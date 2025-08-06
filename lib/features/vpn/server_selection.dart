import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/private_server_entity.dart';
import 'package:lantern/core/models/server_location_entity.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/features/vpn/server_desktop_view.dart';
import 'package:lantern/features/vpn/server_mobile_view.dart';

typedef OnSeverSelected = Function(String selectedServer);

@RoutePage(name: 'ServerSelection')
class ServerSelection extends StatefulHookConsumerWidget {
  const ServerSelection({super.key});

  @override
  ConsumerState<ServerSelection> createState() => _ServerSelectionState();
}

class _ServerSelectionState extends ConsumerState<ServerSelection> {
  TextTheme? _textTheme;
  bool isUserPro = true;

  @override
  Widget build(BuildContext context) {
    var serverLocation = ref.watch(serverLocationNotifierProvider);
    ref.read(serverLocationNotifierProvider.notifier).getLanternServers();
    _textTheme = Theme
        .of(context)
        .textTheme;
    return BaseScreen(
        title: 'server_selection'.i18n, body: _buildBody(serverLocation));
  }

  Widget _buildBody(ServerLocationEntity serverLocation) {
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
          DividerSpace(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
          if (!isUserPro)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: ProBanner(),
            ),
          TabBar(
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Colors.teal.shade900,
            indicatorColor: Colors.transparent,
            dividerHeight: 0,
            unselectedLabelColor: Colors.grey,
            labelStyle: _textTheme!.titleSmall,
            indicator: BoxDecoration(
              color: AppColors.blue2,
              borderRadius: BorderRadius.circular(40),
              shape: BoxShape.rectangle,
              border: Border.all(color: AppColors.blue3, width: 1),
            ),
            tabs: [
              Tab(child: Text('lantern_server'.i18n)),
              Tab(child: Text('private_server'.i18n))
            ],
          ),
          SizedBox(height: 16),
          DividerSpace(),
          SizedBox(height: 16),
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
            icon: AppImagePaths.location,
            label: 'fastest_country'.i18n,
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
          // padding: EdgeInsets.zero,
          child: AppTile(
            contentPadding: EdgeInsets.symmetric(vertical: 5),
            icon: Flag(
              countryCode: serverLocation.serverLocation.countryCode,
              size: Size(40, 28),
            ),
            label: serverLocation.serverName,
            subtitle: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                serverLocation.serverLocation.locationName,
                style: _textTheme!.labelMedium!.copyWith(
                  color: AppColors.gray7,
                ),
              ),
            ),
            trailing: AppRadioButton<String>(
              value: serverLocation.serverName,
              groupValue: serverLocation.serverName,
              onChanged: (value) {},
            ),
          ),
        ),
        DividerSpace(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
        SizedBox(height: 8),
      ],
    );
  }

  Future<void> onSmartLocation(ServerLocationType type) async {
    final result = await ref.read(vpnNotifierProvider.notifier).startVPN();
      result.fold(
          (failure) {
        context.showSnackBar(failure.localizedErrorMessage);
      },
          (success) {
        final serverLocation = ServerLocationEntity(
          serverType: type.name,
          serverName: 'Smart Location',
          autoSelect: true,
          serverLocation: ServerLocationType.auto.name,
        );
        ref
            .read(serverLocationNotifierProvider.notifier)
            .updateServerLocation(serverLocation);
      },
    );
  }
}

class ServerLocationListView extends StatelessWidget {
  final bool userPro;

  const ServerLocationListView({
    super.key,
    required this.userPro,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme
        .of(context)
        .textTheme;
    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('pro_locations'.i18n,
                style: textTheme.labelLarge!.copyWith(
                  color: AppColors.gray8,
                )),
          ),
        ),
        Positioned(
          top: 26,
          bottom: 0,
          right: 0,
          left: 0,
          child: Column(
            children: [
              Expanded(
                child: AppCard(
                  padding: EdgeInsets.zero,
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: 15,
                    itemBuilder: (context, index) {
                      if (PlatformUtils.isDesktop) {
                        return ServerDesktopView(
                          onServerSelected: onServerSelected,
                        );
                      }
                      return ServerMobileView(
                        onServerSelected: onServerSelected,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!userPro)
          Container(
            color: AppColors.white.withValues(alpha: 0.5),
          )
      ],
    );
  }

  void onServerSelected(String selectedServer) {}
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
    _textTheme = Theme
        .of(context)
        .textTheme;

    final serverLocation = ref.watch(serverLocationNotifierProvider);
    final userSelectedServer = useState(serverLocation);
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
        Text('your_server'.i18n,
            style: _textTheme!.titleSmall!.copyWith(
              color: AppColors.gray4,
            )),
        SizedBox(height: 8),
        AppCard(
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
                        if(userSelectedServer.value?.serverName==server.serverName) {
                          appLogger.debug('Already selected this server');
                          context.showSnackBar('server_already_selected'.i18n);
                          return;
                        }
                        onPrivateServerSelected(server);
                        userSelectedServer.value = server;
                        _localStorage
                            .setDefaultPrivateServer(server.serverName);
                      },
                      contentPadding: EdgeInsets.symmetric(vertical: 5),
                      icon: Flag(
                        countryCode: server.serverLocation.countryCode,
                        size: Size(40, 28),
                      ),
                      label: server.serverName,
                      subtitle: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          '${server.serverLocation.locationName} - ${server
                              .externalIp}',
                          style: _textTheme!.labelMedium!.copyWith(
                            color: AppColors.gray7,
                          ),
                        ),
                      ),
                      trailing: AppRadioButton<String>(
                        value: server.serverName,
                        groupValue: (userSelectedServer.value?.serverName ==
                            server.serverName &&
                            serverLocation.serverName == server.serverName)
                            ? server.serverName
                            : null,
                        onChanged: (value) {
                          if(userSelectedServer.value?.serverName==server.serverName) {
                            appLogger.debug('Already selected this server');
                            context.showSnackBar('server_already_selected'.i18n);
                            return;
                          }
                          onPrivateServerSelected(server);
                          userSelectedServer.value = server;
                          _localStorage
                              .setDefaultPrivateServer(server.serverName);
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
        Text('joined_servers'.i18n,
            style: _textTheme!.titleSmall!.copyWith(
              color: AppColors.gray4,
            )),
        SizedBox(height: 8),
        AppCard(
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
                        userSelectedServer.value = server;
                        _localStorage
                            .setDefaultPrivateServer(server.serverName);
                      },
                      contentPadding: EdgeInsets.symmetric(vertical: 5),
                      icon: Flag(
                        countryCode: server.serverLocation.countryCode,
                        size: Size(40, 28),
                      ),
                      label: server.serverName,
                      subtitle: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          '${server.serverLocation.locationName} - ${server
                              .externalIp}',
                          style: _textTheme!.labelMedium!.copyWith(
                            color: AppColors.gray7,
                          ),
                        ),
                      ),
                      trailing: AppRadioButton<String>(
                        value: server.serverName,
                        groupValue: (userSelectedServer.value?.serverName ==
                            server.serverName &&
                            serverLocation.serverName == server.serverName)
                            ? server.serverName
                            : null,
                        onChanged: (value) {
                          onPrivateServerSelected(server);
                          userSelectedServer.value = server;
                          _localStorage
                              .setDefaultPrivateServer(server.serverName);
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
        serverLocation: privateServer.serverLocation);

    ref
        .read(serverLocationNotifierProvider.notifier)
        .updateServerLocation(serverLocation);

    /// Connect to the private server
    final result = await ref.read(vpnNotifierProvider.notifier).connectToServer(
        ServerLocationType.privateServer.name, privateServer.serverName.trim());

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
