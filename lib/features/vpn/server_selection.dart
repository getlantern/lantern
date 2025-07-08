import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/private_server_entity.dart';
import 'package:lantern/core/models/server_location_entity.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/widgets/vpn_status_indicator.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/features/vpn/server_desktop_view.dart';
import 'package:lantern/features/vpn/server_mobile_view.dart';

typedef OnSeverSelected = Function(String selectedServer);

@RoutePage(name: 'ServerSelection')
class ServerSelection extends StatefulWidget {
  const ServerSelection({super.key});

  @override
  State<ServerSelection> createState() => _ServerSelectionState();
}

class _ServerSelectionState extends State<ServerSelection> {
  TextTheme? _textTheme;

  bool isUserPro = true;

  @override
  Widget build(BuildContext context) {
    _textTheme = Theme.of(context).textTheme;
    return BaseScreen(title: 'server_selection'.i18n, body: _buildBody());
  }

  Widget _buildBody() {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // _buildSelectedLocation(),
          // DividerSpace(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
          // SizedBox(height: 8),
          _buildSmartLocation(),
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
              Tab(child: Text('Lantern Server')),
              Tab(child: Text('Private Server'))
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

  Widget _buildSmartLocation() {
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
            label: 'Fastest Country',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppImage(path: AppImagePaths.blot),
                AppRadioButton<bool>(
                  value: true,
                  groupValue: false,
                  onChanged: (value) {},
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedLocation() {
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
            label: 'Fastest Country',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                VPNStatusIndicator(status: VPNStatus.disconnected),
                Radio<bool>(
                  activeColor: AppColors.gray9,
                  value: true,
                  groupValue: false,
                  onChanged: (value) {},
                ),
              ],
            ),
          ),
        ),
      ],
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
    final _textTheme = Theme.of(context).textTheme;
    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('pro_locations'.i18n,
                style: _textTheme!.labelLarge!.copyWith(
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
    _textTheme = Theme.of(context).textTheme;
    final privateServers = _localStorage.getPrivateServer();
    final userSelectedServer = useState(_localStorage.defaultPrivateServer());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(height: 16),
        Text('Your Servers:',
            style: _textTheme!.titleSmall!.copyWith(
              color: AppColors.gray4,
            )),
        SizedBox(height: 8),
        AppCard(
          child: ListView(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            children: privateServers.map(
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
                          '${server.serverLocation.locationName} - ${server.externalIp}',
                          style: _textTheme!.labelMedium!.copyWith(
                            color: AppColors.gray7,
                          ),
                        ),
                      ),
                      trailing: AppRadioButton<String>(
                        value: server.serverName,
                        groupValue: userSelectedServer.value?.serverName,
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
    final result = await ref
        .read(vpnNotifierProvider.notifier)
        .setPrivateServer(
            privateServer.serverLocation, privateServer.serverName.trim());

    result.fold(
      (failure) {
        context.hideLoadingDialog();
        context.showSnackBar(failure.localizedErrorMessage);
      },
      (success) {
        context.hideLoadingDialog();
        context.showSnackBar('Private server set successfully.');
        final serverLocation = ServerLocationEntity(
            serverType: ServerLocationType.privateServer.name,
            serverName: privateServer.serverName,
            autoSelect: false,
            serverLocation: privateServer.serverLocation);

        ref.read(serverLocationNotifierProvider.notifier)
            .updateServerLocation(serverLocation);
      },
    );
  }
}
