import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/private_server.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/widgets/info_row.dart';
import 'package:lantern/features/private_server/provider/manage_server_notifier.dart';
import 'package:lantern/features/private_server/provider/private_server_notifier.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

@RoutePage(name: 'ManagePrivateServer')
class ManagePrivateServer extends StatefulHookConsumerWidget {
  const ManagePrivateServer({super.key});

  @override
  ConsumerState<ManagePrivateServer> createState() =>
      _ManagePrivateServerState();
}

class _ManagePrivateServerState extends ConsumerState<ManagePrivateServer> {
  TextTheme? textTheme;
  String shareAccessKey = "";

  @override
  Widget build(BuildContext context) {
    textTheme = Theme.of(context).textTheme;
    final serversAsync = ref.watch(manageServerProvider);

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
        final myServers = servers.where((s) => !s.isJoined).toList();
        final joinedServers = servers.where((s) => s.isJoined).toList();

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
                    labelColor: Colors.teal.shade900,
                    indicatorColor: Colors.transparent,
                    dividerHeight: 0,
                    unselectedLabelColor: Colors.grey,
                    labelStyle: textTheme!.titleSmall,
                    indicator: BoxDecoration(
                      color: AppColors.blue2,
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: AppColors.blue3, width: 1),
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
                      _buildListView(joinedServers),
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

  Widget buildMyServer(List<PrivateServer> privateServers) {
    return Column(
      children: <Widget>[
        const SizedBox(height: defaultSize),
        InfoRow(
          text: 'access_key_expiration'.i18n,
        ),
        Expanded(child: _buildListView(privateServers)),
      ],
    );
  }

  Widget _buildListView(List<PrivateServer> privateServers) {
    return ListView.builder(
      padding: const EdgeInsets.all(0),
      itemCount: privateServers.length,
      itemBuilder: (context, index) {
        final item = privateServers[index];
        return AppCard(
          margin: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTile(
                label: item.serverName,
                subtitle: Text(item.serverLocationName),
                icon: Flag(countryCode: item.serverCountryCode),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: AppColors.gray9),
                      iconSize: 24,
                      onPressed: () => showDeleteDialog(item.serverName),
                    ),
                  ],
                ),
              ),
              if (!item.isJoined) ...{
                SizedBox(height: 16),
                PrimaryButton(
                    label: 'share_access_key'.i18n,
                    bgColor: AppColors.blue1,
                    icon: AppImagePaths.shareV2,
                    iconColor: AppColors.gray9,
                    showBorder: true,
                    textColor: AppColors.gray9,
                    onPressed: () => onTapShareAccessKey(item)),
                SizedBox(height: 16),
              }
            ],
          ),
        );
      },
    );
  }

  void onTapShareAccessKey(PrivateServer server) {
    if (shareAccessKey.isNotEmpty && shareAccessKey != "") {
      try {
        // If the shareAccessKey is already generated, we don't need to generate it again.
        Map<String, dynamic> tokenData = JwtDecoder.decode(shareAccessKey);
        sharePrivateAccessKey(server, tokenData);
      } catch (e) {
        // If the shareAccessKey is invalid, we need to generate it again.
        showShareAccessKeyDialog(server);
      }
    } else {
      showShareAccessKeyDialog(server);
    }
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
            textColor: AppColors.gray6,
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
        shareAccessKey = accessKey;
        Map<String, dynamic> tokenData = JwtDecoder.decode(accessKey);
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
          textColor: AppColors.gray6,
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
          textColor: AppColors.gray6,
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
    final lantern = ref.read(lanternServiceProvider);

    final res = await lantern.updatePrivateServerName(serverName, newName);
    context.hideLoadingDialog();

    res.fold(
      (failure) {
        context.showSnackBarError(failure.localizedErrorMessage);
      },
      (_) {
        ref.invalidate(manageServerProvider);
      },
    );
  }

  Future<void> onDelete(String serverName) async {
    context.showLoadingDialog();
    await ref.read(manageServerProvider.notifier).deleteServer(serverName);
    context.hideLoadingDialog();
  }
}
