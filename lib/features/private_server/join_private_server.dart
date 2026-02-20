import 'dart:convert';

import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/entity/private_server_entity.dart';

import 'package:lantern/core/models/private_server_status.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/widgets/app_rich_text.dart';
import 'package:lantern/core/widgets/info_row.dart';
import 'package:lantern/features/private_server/provider/private_server_notifier.dart';

@RoutePage(name: 'JoinPrivateServer')
class JoinPrivateServer extends StatefulHookConsumerWidget {
  final Map<String, String>? deepLinkData;

  const JoinPrivateServer({super.key, this.deepLinkData});

  @override
  ConsumerState<JoinPrivateServer> createState() => _JoinPrivateServerState();
}

class _JoinPrivateServerState extends ConsumerState<JoinPrivateServer> {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final accessKeyController =
        useTextEditingController(text: widget.deepLinkData?['accessKey'] ?? '');
    final name = (widget.deepLinkData?['alias'] ?? '').replaceAll('-', ' ');
    final nameController = useTextEditingController(text: name);
    final buttonValid = useState(
        accessKeyController.text.isNotEmpty && nameController.text.isNotEmpty);
    final serverState = ref.watch(privateServerProvider);

    useEffect(() {
      if (serverState.status == 'EventTypeProvisioningCompleted') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          appLogger.info("Private server deployment completed successfully.",
              serverState.data);
          final data = jsonDecode(serverState.data!);
          final serverData = PrivateServerEntity.fromJson(data);
          sl<LocalStorageService>()
              .savePrivateServer(serverData.copyWith(isJoined: true));
          showSuccessDialog(nameController.text);
        });
      }

      return null;
    }, [serverState.status]);
    return BaseScreen(
      title: 'join_private_server'.i18n,
      body: SingleChildScrollView(
        child: Column(children: <Widget>[
          // SizedBox(height: 16),
          InfoRow(
            backgroundColor: context.bgPromo,
            showLeadingIcon: false,
            text: '',
            child: Row(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: AppImage(
                    path: AppImagePaths.warning,
                    width: 20,
                    height: 20,
                  ),
                ),
                Expanded(
                  child: AppRichText(
                    boldUnderline: true,
                    texts: 'private_server_warning'.i18n,
                    boldTexts: 'learn_more'.i18n,
                    boldOnPressed: showTrustDialog,
                  ),
                )
              ],
            ),
          ),
          SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "1. ${'name_your_server'.i18n}",
                  style: textTheme.titleMedium,
                ),
                SizedBox(height: 16),
                AppTextField(
                  label: 'server_nickname'.i18n,
                  hintText: "server_name".i18n,
                  controller: nameController,
                  onChanged: (value) {
                    buttonValid.value = (value.isNotEmpty &&
                        accessKeyController.text.isNotEmpty);
                  },
                  prefixIcon: AppImage(path: AppImagePaths.server),
                ),
                SizedBox(height: 4),
                Center(
                  child: Text(
                    "how_server_appears".i18n,
                    style: textTheme.labelMedium!.copyWith(
                      color: context.textDisabled,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "2.  ${'server_access_key'.i18n}",
                  style: textTheme.titleMedium,
                ),
                SizedBox(height: 16),
                AppTextField(
                  hintText: "access_key".i18n,
                  label: 'access_key'.i18n,
                  controller: accessKeyController,
                  prefixIcon: AppImage(path: AppImagePaths.key),
                  onChanged: (value) {
                    buttonValid.value =
                        (value.isNotEmpty && nameController.text.isNotEmpty);
                  },
                  suffixIcon: PlatformUtils.isMobile
                      ? GestureDetector(
                          onTap: () {
                            appRouter.push(QrCodeScanner()).then((value) {
                              if (value != null && value is String) {
                                accessKeyController.text = value;
                                buttonValid.value = (value.isNotEmpty &&
                                    nameController.text.isNotEmpty);
                              }
                            });
                          },
                          child: AppImage(path: AppImagePaths.qrCodeScanner),
                        )
                      : GestureDetector(
                          onTap: () {
                            pasteFromClipboard().then((value) {
                              if (value.isNotEmpty) {
                                accessKeyController.text = value;
                                buttonValid.value = (value.isNotEmpty &&
                                    nameController.text.isNotEmpty);
                              }
                            });
                          },
                          child: AppImage(path: AppImagePaths.copy),
                        ),
                ),
                SizedBox(height: 16),
                PrimaryButton(
                  enabled: buttonValid.value,
                  label: 'join_server'.i18n,
                  onPressed: () => onJoinServer(
                      accessKeyController.text, nameController.text),
                ),
              ],
            ),
          )
        ]),
      ),
    );
  }

  void showTrustDialog() {
    final textTheme = Theme.of(context).textTheme;
    AppDialog.customDialog(
        context: context,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(height: 16),
            AppImage(
              path: AppImagePaths.security,
              height: 40,
              color: context.textPrimary,
            ),
            SizedBox(height: 16),
            Text(
              'trust_server_operator'.i18n,
              style: textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              'trust_server_operator_message_one'.i18n,
              style: textTheme.bodyMedium,
            ),
            SizedBox(height: 16),
            Text(
              'trust_server_operator_message_two'.i18n,
              style: textTheme.bodyMedium,
            ),
            SizedBox(height: 16),
            Text(
              'trust_server_operator_message_three'.i18n,
              style: textTheme.bodyMedium,
            ),
          ],
        ),
        action: [
          AppTextButton(
            label: 'got_it'.i18n,
            onPressed: () {
              appRouter.pop();
            },
          )
        ]);
  }

  Future<void> onJoinServer(String urls, String serverName) async {
    context.showLoadingDialog();
    final result = await ref
        .read(privateServerProvider.notifier)
        .addServerBasedOnURLs(urls, true, serverName);
    result.fold(
      (error) {
        appLogger.error("Failed to join private server: $error");
        context.hideLoadingDialog();
        AppDialog.errorDialog(
            context: context,
            title: 'error'.i18n,
            content: error.localizedErrorMessage);
      },
      (success) {
        context.hideLoadingDialog();
        appLogger.info("Successfully started joining private server.");
      },
    );
  }

  void showSuccessDialog(String name) {
    final textTheme = Theme.of(context).textTheme;
    AppDialog.customDialog(
      context: context,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(height: 24),
          Center(
              child: AppImage(
            path: AppImagePaths.roundCorrect,
            height: 36,
          )),
          SizedBox(height: 16),
          Text(
            'private_server_ready'.i18n,
            style: textTheme.titleLarge,
          ),
          SizedBox(height: 16),
          Text(
            'private_server_ready_message'.i18n.fill([name]),
            style: textTheme.bodyLarge,
          ),
        ],
      ),
      action: [
        AppTextButton(
          label: "close".i18n,
          onPressed: () {
            appRouter.popUntilRoot();
          },
          textColor: context.textDisabled,
        ),
        AppTextButton(
          label: "go_to_server_locations".i18n,
          textColor: AppColors.blue6,
          onPressed: () {
            appRouter.pushAndPopUntil(
              ServerSelection(),
              predicate: (route) => route.isFirst,
            );
          },
        ),
      ],
    );
  }
}
