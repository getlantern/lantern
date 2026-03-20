import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/models/private_server.dart';
import 'package:lantern/core/widgets/info_row.dart';
import 'package:lantern/features/private_server/provider/manage_server_notifier.dart';
import 'package:lantern/features/private_server/provider/private_server_notifier.dart';
import 'package:lantern/features/vpn/provider/available_servers_notifier.dart';

@RoutePage(name: 'ManagePrivateServer')
class ManagePrivateServer extends StatefulHookConsumerWidget {
  const ManagePrivateServer({super.key});

  @override
  ConsumerState<ManagePrivateServer> createState() =>
      _ManagePrivateServerState();
}

class _ManagePrivateServerState extends ConsumerState<ManagePrivateServer> {
  TextTheme? textTheme;

  /// Cache of generated access keys keyed by server tag.
  /// Avoids redundant API calls when the user taps share on the same server.
  final Map<String, String> _accessKeyCache = {};

  @override
  Widget build(BuildContext context) {
    textTheme = Theme.of(context).textTheme;
    final serversAsync = ref.watch(availableServersProvider);

    return serversAsync.when(
      loading: () => BaseScreen(
        title: 'manage_private_servers'.i18n,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, st) => BaseScreen(
        title: 'manage_private_servers'.i18n,
        body: Center(child: Text(err.toString())),
      ),
      data: (servers) {
        final allServers = servers.user.locations.values.toList();
        final joinedServers = allServers
            .where((loc) => servers.user.credentials[loc.tag]?.isJoined == true)
            .toList();
        final myServers = allServers
            .where((loc) => servers.user.credentials[loc.tag]?.isJoined != true)
            .toList();

        return BaseScreen(
          title: 'manage_private_servers'.i18n,
          body: DefaultTabController(
            length: 2,
            child: Column(
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
                    labelStyle: textTheme!.titleSmall,
                    indicator: BoxDecoration(
                      color: context.actionTabbarBg,
                      borderRadius: BorderRadius.circular(40),
                      shape: BoxShape.rectangle,
                      border: Border.all(
                          color: context.actionTabbarBorder, width: 1),
                    ),
                    tabs: [
                      Tab(child: Text('my_servers'.i18n)),
                      Tab(child: Text('joined_servers'.i18n)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                DividerSpace(padding: EdgeInsets.zero),
                Expanded(
                  child: TabBarView(
                    children: [
                      buildMyServer(myServers),
                      Padding(
                        padding: const EdgeInsets.only(top: defaultSize),
                        child: _buildListView(
                          joinedServers,
                          showShareAccessKey: false,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildMyServer(List<Location_> myServers) {
    return Column(
      children: <Widget>[
        const SizedBox(height: 8),
        InfoRow(
          text: 'access_key_expiration'.i18n,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _buildListView(
            myServers,
            showShareAccessKey: true,
          ),
        ),
      ],
    );
  }

  Widget _buildListView(
    List<Location_> myServers, {
    required bool showShareAccessKey,
  }) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: myServers.length,
      itemBuilder: (context, index) {
        final item = myServers[index];
        return AppCard(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTile(
                label: item.tag,
                subtitle: Text(item.city),
                icon: Flag(countryCode: item.countryCode),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          color: context.textPrimary),
                      iconSize: 24,
                      onPressed: () => showDeleteDialog(item.tag),
                    ),
                  ],
                ),
              ),
              if (showShareAccessKey) ...{
                SizedBox(height: 8),
                SecondaryButton(
                  icon: AppImagePaths.share,
                  foregroundColor: context.actionTonalText,
                  label: 'share_access_key'.i18n,
                  bgColor: context.actionTonalBg,
                  onPressed: () => onTapShareAccessKey(item),
                ),
                SizedBox(height: 8),
              }
            ],
          ),
        );
      },
    );
  }

  void onTapShareAccessKey(Location_ location) {
    final servers = ref.read(availableServersProvider).value;

    if (servers == null) {
      appLogger.error('Servers data is null, cannot share access key');
      return;
    }

    final matchingOutbounds =
        servers.user.outbounds.where((o) => o.tag == location.tag);
    if (matchingOutbounds.isEmpty) {
      appLogger.error(
          'No outbound found for tag: ${location.tag}, cannot share access key');
      return;
    }
    final userServer = matchingOutbounds.first;

    final credential = servers.user.credentials[location.tag];
    if (credential == null || credential.accessToken.isEmpty) {
      appLogger.error('No access token for tag: ${location.tag}');
      AppDialog.errorDialog(
        context: context,
        title: 'error'.i18n,
        content: 'access_token_missing'.i18n,
      );
      return;
    }

    final privateServer = PrivateServer(
      serverName: userServer.tag,
      externalIp: userServer.server,
      port: credential.port,
      accessToken: credential.accessToken,
      serverLocationName: location.city,
      serverCountryCode: location.countryCode,
      protocol: location.protocol,
      isJoined: credential.isJoined,
    );
    final cachedKey = _accessKeyCache[location.tag];
    if (cachedKey != null) {
      appLogger.info('Reusing cached access key for tag: ${location.tag}');
      try {
        final tokenData = JwtDecoder.decode(cachedKey);
        sharePrivateAccessKey(privateServer, tokenData);
        return;
      } catch (e) {
        appLogger.warning(
            'Cached access key invalid for tag: ${location.tag}, regenerating');
        _accessKeyCache.remove(location.tag);
      }
    }

    showShareAccessKeyDialog(privateServer);
  }

  void showShareAccessKeyDialog(PrivateServer server) {
    final inviteNameController = TextEditingController();
    AppDialog.customDialog(
        context: context,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(height: 16),
            Text(
              'set_server_alias'.i18n,
              style: textTheme!.headlineMedium,
            ),
            SizedBox(height: defaultSize),
            Text(
              'this_name_pre_filled'.i18n,
              style: textTheme!.bodyMedium,
            ),
            SizedBox(height: size24),
            AppTextField(
              label: 'server_alias'.i18n,
              prefixIcon: AppImagePaths.server,
              controller: inviteNameController,
              hintText: '',
            )
          ],
        ),
        action: [
          AppTextButton(
            label: 'cancel'.i18n,
            textColor: context.textDisabled,
            onPressed: () {
              appRouter.pop();
            },
          ),
          AppTextButton(
            label: 'generate_access_key'.i18n,
            onPressed: () {
              generateAccessKey(server, inviteNameController.text.trim());
              appRouter.pop();
            },
          )
        ]);
  }

  Future<void> generateAccessKey(
      PrivateServer server, String inviteName) async {
    if (inviteName.isEmpty) {
      context.showSnackBar('server_alias_cannot_be_empty'.i18n);
      return;
    }
    context.showLoadingDialog();
    final result = await ref
        .read(privateServerProvider.notifier)
        .inviteToServerManagerInstance(
            server.externalIp, server.port, server.accessToken, inviteName);

    result.fold(
      (failure) {
        context.hideLoadingDialog();
        AppDialog.errorDialog(
          context: context,
          title: 'error'.i18n,
          content: failure.localizedErrorMessage,
        );
      },
      (accessKey) {
        context.hideLoadingDialog();
        _accessKeyCache[server.serverName] = accessKey;
        appLogger
            .info('Access key generated and cached for: ${server.serverName}');
        final tokenData = JwtDecoder.decode(accessKey);
        sharePrivateAccessKey(server, tokenData);
      },
    );
  }

  void showRenameDialog(String serverName) {
    final textController = TextEditingController();
    AppDialog.customDialog(
      context: context,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(height: 16),
          Text(
            'rename_server'.i18n,
            style: textTheme!.titleLarge,
          ),
          SizedBox(height: 16),
          AppTextField(
            label: 'server_name'.i18n,
            onChanged: (value) {},
            controller: textController,
            prefixIcon: AppImagePaths.server,
            hintText: serverName,
          ),
          SizedBox(height: 16),
        ],
      ),
      action: [
        AppTextButton(
          label: 'cancel',
          textColor: context.textDisabled,
          onPressed: () {
            appRouter.pop();
          },
        ),
        AppTextButton(
          label: 'rename',
          onPressed: () {
            appRouter.pop();
            onRename(serverName, textController.text.trim());
          },
        ),
      ],
    );
  }

  void showDeleteDialog(String serverName) {
    AppDialog.customDialog(
      context: context,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(height: 16),
          AppImage(
            path: AppImagePaths.delete,
            height: 40,
          ),
          Text(
            'remove_server_?'.i18n,
            style: textTheme!.titleLarge,
          ),
          SizedBox(height: 16),
          Text('remove_server_message'.i18n.fill([serverName])),
          SizedBox(height: 16),
        ],
      ),
      action: [
        AppTextButton(
          label: 'cancel'.i18n,
          textColor: context.textDisabled,
          onPressed: () {
            appRouter.pop();
          },
        ),
        AppTextButton(
          label: 'remove'.i18n,
          textColor: AppColors.red7,
          onPressed: () {
            appRouter.pop();
            onDelete(serverName);
          },
        ),
      ],
    );
  }

  void onRename(String serverName, String newName) async {
    if (newName.isEmpty) return;
    context.showLoadingDialog();
    final res = await ref
        .read(manageServerProvider.notifier)
        .renameServer(serverName, newName);
    if (!mounted) return;
    context.hideLoadingDialog();
    res.fold(
      (failure) => context.showSnackBarError(failure.localizedErrorMessage),
      (r) {
        appLogger.info('Server renamed: $serverName to $newName');
      },
    );
  }

  Future<void> onDelete(String serverName) async {
    context.showLoadingDialog();
    final res =
        await ref.read(manageServerProvider.notifier).deleteServer(serverName);
    if (!mounted) return;
    context.hideLoadingDialog();
    res.fold(
      (failure) => context.showSnackBarError(failure.localizedErrorMessage),
      (r) {
        appLogger.info('Server deleted: $serverName');
      },
    );
  }
}
