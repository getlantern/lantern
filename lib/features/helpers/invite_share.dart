import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/features/helpers/approve_helper_sheet.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';
import 'package:lantern/lantern/lantern_platform_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

/// Copies an invite link. On Android it is marked sensitive, so Android 13+
/// hides it from the clipboard preview and keyboard clipboard history; the
/// link is a secret.
Future<void> copySensitiveText(String text) async {
  if (PlatformUtils.isAndroid) {
    await sl<LanternPlatformService>().copySensitiveText(text);
    return;
  }
  await Clipboard.setData(ClipboardData(text: text));
}

/// One invite: share it as a link or a QR code, then compare codes once a
/// friend opens it. It reads the invite from the engine's view by ID, so the
/// link never travels in route arguments.
@RoutePage(name: 'InviteShare')
class InviteShare extends ConsumerWidget {
  const InviteShare({super.key, required this.inviteId});

  final String inviteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(helpersProvider.select((s) => s.view));
    final invite = view.invites.where((i) => i.id == inviteId).firstOrNull;
    final textTheme = Theme.of(context).textTheme;

    if (invite == null) {
      return BaseScreen(
        title: 'invite_share_title'.i18n,
        body: Center(
          child: Text('invite_gone'.i18n, key: const Key('invite.gone')),
        ),
      );
    }
    if (invite.claimed) {
      return BaseScreen(
        title: 'invite_share_title'.i18n,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: defaultSize),
            Text('invite_claimed_title'.i18n, style: textTheme.titleLarge),
            const SizedBox(height: defaultSize),
            PrimaryButton(
              label: 'invite_compare_codes'.i18n,
              onPressed: () => showApproveHelperSheet(context, invite),
            ),
          ],
        ),
      );
    }

    final message = 'invite_share_message'.i18n.fill([
      view.myName,
      invite.link,
    ]);
    return BaseScreen(
      title: 'invite_share_title'.i18n,
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: defaultSize),
        children: [
          Text(
            'invite_share_body'.i18n,
            style: textTheme.bodyMedium!.copyWith(color: context.textSecondary),
          ),
          const SizedBox(height: 24),
          KeyedSubtree(
            key: const Key('invite.share'),
            child: PrimaryButton(
              label: 'invite_share_button'.i18n,
              onPressed: () =>
                  SharePlus.instance.share(ShareParams(text: message)),
            ),
          ),
          const SizedBox(height: 8),
          SecondaryButton(
            label: 'invite_copy_link'.i18n,
            onPressed: () async {
              try {
                await copySensitiveText(invite.link);
                if (context.mounted) {
                  context.showSnackBar('invite_link_copied'.i18n);
                }
              } catch (_) {
                if (context.mounted) {
                  context.showSnackBarError('helper_error_copy'.i18n);
                }
              }
            },
          ),
          const SizedBox(height: 24),
          Center(
            child: QrImageView(
              key: const Key('invite.qr'),
              data: invite.link,
              version: QrVersions.auto,
              size: 220,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('invite_qr_hint'.i18n, style: textTheme.labelMedium),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text('invite_waiting'.i18n)),
            ],
          ),
        ],
      ),
    );
  }
}
