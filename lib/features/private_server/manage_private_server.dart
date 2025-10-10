import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/entity/private_server_entity.dart';

import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/widgets/info_row.dart';
import 'package:lantern/features/private_server/provider/manage_server_notifier.dart';
import 'package:lantern/features/private_server/provider/private_server_notifier.dart';

@RoutePage(name: 'ManagePrivateServer')
class ManagePrivateServer extends StatefulHookConsumerWidget {
  const ManagePrivateServer({super.key});

  @override
  ConsumerState<ManagePrivateServer> createState() =>
      _ManagePrivateServerState();
}

class _ManagePrivateServerState extends ConsumerState<ManagePrivateServer> {
  final _localStorage = sl<LocalStorageService>();
  TextTheme? textTheme;
  String shareAccessKey = "";

  @override
  Widget build(BuildContext context) {
    textTheme = Theme.of(context).textTheme;
    final servers = ref.watch(manageServerNotifierProvider);
    appLogger.debug("Servers: $servers");
    final myServer = servers.where((element) => !element.isJoined).toList();
    final joinedServer = servers.where((element) => element.isJoined).toList();

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
                  shape: BoxShape.rectangle,
                  border: Border.all(color: AppColors.blue3, width: 1),
                ),
                tabs: [
                  Tab(child: Text('my_servers'.i18n)),
                  Tab(child: Text('joined_servers'.i18n))
                ],
              ),
            ),
            const SizedBox(height: 8),
            DividerSpace(padding: EdgeInsets.zero),
            Expanded(
              child: TabBarView(
                children: [
                  buildMyServer(myServer),
                  _buildListView(joinedServer),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildMyServer(List<PrivateServerEntity> privateServers) {
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

  Widget _buildListView(List<PrivateServerEntity> privateServers) {
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
                contentPadding: const EdgeInsets.all(0),
                label: item.serverName,
                subtitle: Text(item.serverLocation.locationName),
                icon: Flag(countryCode: item.serverLocation.countryCode),
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

  void onTapShareAccessKey(PrivateServerEntity server) {
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

  void showShareAccessKeyDialog(PrivateServerEntity server) {
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
      PrivateServerEntity server, String inviteName) async {
    if (inviteName.isEmpty) {
      context.showSnackBar('server_alias_cannot_be_empty'.i18n);

      return;
    }
    context.showLoadingDialog();
    final result = await ref
        .read(privateServerNotifierProvider.notifier)
        .inviteToServerManagerInstance(
            server.externalIp, server.port, server.accessToken, inviteName);

    result.fold(
      (failure) {
        context.hideLoadingDialog();
        if (failure.localizedErrorMessage
            .contains('failed to get trusted server fingerprint')) {
          showFingerprintChangedDialog(server);
          return;
        }
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

  void showFingerprintChangedDialog(PrivateServerEntity server) {
    AppDialog.customDialog(
        context: context,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(height: 16),
            Center(
              child: AppImage(
                  path: AppImagePaths.warning,
                  height: 40,
                  color: AppColors.yellow4),
            ),
            SizedBox(height: defaultSize),
            Text('identity_changed'.i18n.fill([server.serverName]),
                style:
                    textTheme!.headlineSmall!.copyWith(color: AppColors.gray7),
                textAlign: TextAlign.center),
            SizedBox(height: defaultSize),
            Text(
              'identity_changed_message'.i18n.fill([server.serverName]),
              style: textTheme!.bodyMedium!.copyWith(color: AppColors.gray7),
            ),
            SizedBox(height: defaultSize),
            Text(
              'recommendation'.i18n,
              style: AppTextStyles.bodyMediumBold!
                  .copyWith(color: AppColors.gray7),
            ),
            Text(
              'recommendation_message'.i18n.fill([server.serverName]),
              style: textTheme!.bodyMedium!.copyWith(color: AppColors.gray7),
            )
          ],
        ),
        action: [
          AppTextButton(
            label: 'cancel'.i18n,
            textColor: AppColors.gray6,
            underLine: false,
            onPressed: () {
              appRouter.pop();
            },
          ),
          AppTextButton(
            label: 'remove_server'.i18n,
            textColor: AppColors.red7,
            onPressed: () {
              onDelete(server.serverName);
              appRouter.pop();
            },
          )
        ]);
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

  void onRename(String serverName, String newName) {
    _localStorage.updatePrivateServerName(serverName, newName);
    setState(() {});
  }

  void onDelete(String serverName) {
    ref.read(manageServerNotifierProvider.notifier).deleteServer(serverName);
  }
}
