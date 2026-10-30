import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/features/helpers/approve_helper_sheet.dart';
import 'package:lantern/features/helpers/models/helpers_view.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';
import 'package:lantern/lantern/lantern_platform_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

/// Copies an invite link. On Android it is marked sensitive, so Android 13+
/// hides it from the clipboard preview and keyboard clipboard history; the
/// link is a secret.
Future<void> copySensitiveText(String text) async {
  if (debugCopyAsAndroid ?? PlatformUtils.isAndroid) {
    await sl<LanternPlatformService>().copySensitiveText(text);
    return;
  }
  await Clipboard.setData(ClipboardData(text: text));
}

/// The text shared with an invite: it names the inviter as they named
/// themselves for this invite, or by the last name used for one saved
/// before names were kept per invite.
String inviteShareMessage(HelpersView view, HelperInviteView invite) =>
    'invite_share_message'.i18n.fill([
      invite.inviterName.isNotEmpty ? invite.inviterName : view.myName,
      invite.link,
    ]);

/// Lets a test take the Android path of [copySensitiveText].
@visibleForTesting
bool? debugCopyAsAndroid;

/// Lets a test see what [shareInvite] would hand the share sheet.
@visibleForTesting
Future<void> Function(ShareParams params)? debugShareInvite;

/// Opens the share sheet anchored on [anchor]'s widget. iPad presents it as
/// a popover and throws without a non-empty origin.
Future<void> shareInvite(BuildContext anchor, String message) async {
  final box = anchor.findRenderObject() as RenderBox?;
  final origin = box != null && box.hasSize && !box.size.isEmpty
      ? box.localToGlobal(Offset.zero) & box.size
      : const Rect.fromLTWH(0, 0, 1, 1);
  final params = ShareParams(text: message, sharePositionOrigin: origin);
  final share = debugShareInvite;
  if (share != null) return share(params);
  await SharePlus.instance.share(params);
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

    if (invite == null || invite.expired) {
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
            KeyedSubtree(
              key: const Key('invite.compare'),
              child: PrimaryButton(
                label: 'invite_compare_codes'.i18n,
                onPressed: () async {
                  final decided = await showApproveHelperSheet(context, invite);
                  // The invite is used now; go back to the helpers list
                  // rather than staying on "used or expired".
                  if (decided && context.mounted) {
                    await Navigator.of(context).maybePop();
                  }
                },
              ),
            ),
          ],
        ),
      );
    }

    final message = inviteShareMessage(view, invite);
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
            child: Builder(
              builder: (buttonContext) => PrimaryButton(
                label: 'invite_share_button'.i18n,
                onPressed: () => shareInvite(buttonContext, message),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SecondaryButton(
            key: const Key('invite.copy'),
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
