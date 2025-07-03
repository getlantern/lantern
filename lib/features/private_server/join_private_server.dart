import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
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
    final nameController = useTextEditingController();
    final buttonValid = useState(false);
    final serverState = ref.watch(privateServerNotifierProvider);
    return BaseScreen(
      title: 'join_private_server'.i18n,
      body: SingleChildScrollView(
        child: Column(children: <Widget>[
          SizedBox(height: 16),
          InfoRow(
            backgroundColor: AppColors.yellow1,
            text: '',
            onPressed: () {},
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
                    texts: 'Only add servers run by people you trust ',
                    boldTexts: 'Learn More.',
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
                      color: AppColors.gray6,
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
                  suffixIcon: AppImagePaths.copy,
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
              color: AppColors.gray9,
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

  void onJoinServer(String accessKey, String name) {}
}
