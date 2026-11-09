import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/widgets/info_row.dart';
import 'package:lantern/features/helpers/approve_helper_dialog.dart';
import 'package:lantern/features/helpers/helper_errors.dart';
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

/// "Invite a Personal Proxy": the name the friend knows the user by, then
/// the link to share, with a QR code a tap away for sharing in person. The
/// invite is made with the name, at once when the name is known already,
/// else at the first Share, copy or QR code; a name changed later is saved
/// to the invite before the link next goes out. It reads the invite from the
/// engine's view by ID, so the link never travels in route arguments. Once a
/// friend opens the link, the app-wide prompt asks to approve them, and this
/// screen closes once that is decided.
@RoutePage(name: 'InviteShare')
class InviteShare extends HookConsumerWidget {
  const InviteShare({super.key, this.inviteId});

  /// The invite to show, or null to make one here.
  final String? inviteId;

  /// How long the copy icon shows its check.
  @visibleForTesting
  static Duration copiedFor = const Duration(seconds: 1);

  /// How often an open invite's expiry is checked against the clock.
  @visibleForTesting
  static Duration expiryCheckEvery = const Duration(seconds: 5);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(helpersProvider.select((s) => s.view));
    final notifier = ref.read(helpersProvider.notifier);
    final textTheme = Theme.of(context).textTheme;
    final id = useState(inviteId);
    final invite = view.invites.where((i) => i.id == id.value).firstOrNull;
    final nameCtl = useTextEditingController(
      text: invite != null && invite.inviterName.isNotEmpty
          ? invite.inviterName
          : view.myName,
    );
    final link = invite != null && !invite.expired ? invite.link : '';
    final linkCtl = useTextEditingController(text: link);
    final nameError = useState(false);
    // The user typed in the name field, so a name loaded later is not put
    // over theirs.
    final nameTyped = useRef(false);
    // Rebuilds when an invite was found expired as its link was about to go
    // out, so the gone state shows. Expiry itself is read from the clock.
    final expiryChecks = useState(0);
    final copied = useState(false);
    final sawClaimed = useRef(false);
    // The approval this screen reopened, which completes only after its
    // Connect Now has finished with this screen's context.
    final approving = useRef<Future<bool>?>(null);
    if (invite?.claimed ?? false) sawClaimed.value = true;
    useEffect(() {
      linkCtl.text = link;
      return null;
    }, [link]);
    // One make or rename at a time; another waits for it, then checks again.
    final inflight = useRef<Future<HelperInviteView?>?>(null);

    HelperInviteView? current() => ref
        .read(helpersProvider)
        .view
        .invites
        .where((i) => i.id == id.value)
        .firstOrNull;

    Future<HelperInviteView?> makeOrRename(String name) async {
      final inv = current();
      final HelperResult r;
      if (id.value == null) {
        r = await notifier.createInvite(name);
        final made = r.data['invite_id'];
        if (r.ok && made is String && context.mounted) id.value = made;
      } else if (inv != null && inv.inviterName != name) {
        r = await notifier.renameInvite(inv.id, name);
      } else {
        return inv;
      }
      if (!context.mounted) return null;
      if (!r.ok || id.value == null) {
        if (r.error == 'bad_name') {
          nameError.value = true;
        } else {
          context.showSnackBarError(helperErrorText(r.error ?? 'unavailable'));
        }
        return null;
      }
      return current();
    }

    /// The invite with the name typed, made or renamed as needed; null, with
    /// the reason shown, when there is none or it has expired.
    Future<HelperInviteView?> ready() async {
      while (inflight.value != null) {
        await inflight.value;
        if (!context.mounted) return null;
      }
      final name = nameCtl.text.trim();
      if (name.isEmpty) {
        nameError.value = true;
        return null;
      }
      final f = makeOrRename(name);
      inflight.value = f;
      final HelperInviteView? inv;
      try {
        inv = await f;
      } finally {
        if (inflight.value == f) inflight.value = null;
      }
      if (inv == null || !inv.expired) return inv;
      if (context.mounted) expiryChecks.value++;
      return null;
    }

    // A name known already, or loaded with the view after this screen
    // opened, makes the link at once.
    useEffect(() {
      if (id.value != null || nameTyped.value) return null;
      if (nameCtl.text.trim().isEmpty && view.myName.isNotEmpty) {
        nameCtl.text = view.myName;
      }
      if (nameCtl.text.trim().isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) unawaited(ready());
        });
      }
      return null;
    }, [view.myName]);

    // Decided from the approval prompt: nothing is left to share. Leave
    // once nothing covers this screen, such as the success dialog.
    final decided = sawClaimed.value && invite == null;
    useEffect(() {
      if (!decided) return null;
      final timer = Timer.periodic(const Duration(milliseconds: 250), (t) {
        if (!context.mounted) return t.cancel();
        if (approving.value != null) return;
        if (ModalRoute.of(context)?.isCurrent ?? false) {
          t.cancel();
          unawaited(Navigator.of(context).maybePop());
        }
      });
      return timer.cancel;
    }, [decided]);

    // Show the gone state when the open invite runs out, not at the next
    // refresh. Expiry is read from the wall clock, which can move either
    // way, so check it every few seconds and rebuild when it flips.
    final expiresUnix = invite == null || invite.claimed
        ? 0
        : invite.expiresUnix;
    useEffect(() {
      if (expiresUnix <= 0) return null;
      bool expiredNow() =>
          expiresUnix <= DateTime.now().millisecondsSinceEpoch ~/ 1000;
      var wasExpired = expiredNow();
      final timer = Timer.periodic(expiryCheckEvery, (_) {
        final expired = expiredNow();
        if (expired == wasExpired || !context.mounted) return;
        wasExpired = expired;
        expiryChecks.value++;
      });
      return timer.cancel;
    }, [expiresUnix]);

    if (id.value != null && (invite == null || invite.expired)) {
      return BaseScreen(
        title: 'invite_personal_proxy'.i18n,
        body: Center(
          child: Text('invite_gone'.i18n, key: const Key('invite.gone')),
        ),
      );
    }

    Future<void> copy() async {
      final inv = await ready();
      if (inv == null || inv.link.isEmpty || !context.mounted) return;
      try {
        await copySensitiveText(inv.link);
      } catch (_) {
        if (context.mounted) {
          context.showSnackBarError('helper_error_copy'.i18n);
        }
        return;
      }
      if (!context.mounted) return;
      copied.value = true;
      await Future<void>.delayed(copiedFor);
      if (context.mounted) copied.value = false;
    }

    Future<void> share(BuildContext anchor) async {
      final inv = await ready();
      if (inv == null || inv.link.isEmpty || !anchor.mounted) return;
      await shareInvite(
        anchor,
        inviteShareMessage(ref.read(helpersProvider).view, inv),
      );
    }

    Future<void> showQr() async {
      final inv = await ready();
      if (inv == null || inv.link.isEmpty || !context.mounted) return;
      await showInviteQrDialog(context, inv.link);
    }

    final helperStyle = textTheme.labelMedium!.copyWith(
      color: context.textTertiary,
    );
    final pending = invite != null && !invite.claimed;
    // A claimed invite has no link left to copy or show.
    final claimed = invite != null && invite.claimed;

    return BaseScreen(
      title: 'invite_personal_proxy'.i18n,
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: defaultSize),
        children: [
          AppCard(
            key: const Key('invite.card'),
            padding: const EdgeInsets.all(defaultSize),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('invite_share_title'.i18n, style: textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'invite_share_steps'.i18n,
                  style: textTheme.bodyMedium!.copyWith(
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  fieldKey: const Key('invite.name'),
                  controller: nameCtl,
                  label: 'helpers_your_name_label'.i18n,
                  hintText: 'helpers_your_name_hint'.i18n,
                  prefixIcon: Icons.person_outline,
                  maxLength: 60,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) {
                    nameTyped.value = true;
                    nameError.value = false;
                  },
                  onSubmitted: (_) => unawaited(ready()),
                ),
                if (nameError.value)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      helperErrorText('bad_name'),
                      key: const Key('invite.name.error'),
                      style: textTheme.bodySmall!.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                // Read-only: a tap copies it, as does the copy icon. No
                // selection menu, whose Copy would skip copySensitiveText.
                AppTextField(
                  fieldKey: const Key('invite.link'),
                  controller: linkCtl,
                  label: 'invite_link_label'.i18n,
                  hintText: 'invite_link_hint'.i18n,
                  prefixIcon: Icons.link,
                  enableSuggestions: false,
                  enableIMEPersonalizedLearning: false,
                  autocorrect: false,
                  enableInteractiveSelection: false,
                  onTap: claimed ? null : copy,
                  suffixIcon: claimed
                      ? null
                      : IconButton(
                          key: const Key('invite.copy'),
                          tooltip: 'invite_copy_link'.i18n,
                          icon: AnimatedCrossFade(
                            duration: const Duration(milliseconds: 400),
                            firstCurve: Curves.bounceOut,
                            crossFadeState: copied.value
                                ? CrossFadeState.showSecond
                                : CrossFadeState.showFirst,
                            firstChild: const AppImage(
                              path: AppImagePaths.copy,
                            ),
                            secondChild: Icon(
                              Icons.check_circle,
                              key: const Key('invite.copied'),
                              color: context.statusSuccessBg,
                            ),
                          ),
                          onPressed: copy,
                        ),
                ),
                if (!claimed) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${'invite_link_expiry'.i18n} · ',
                          style: helperStyle,
                        ),
                        Semantics(
                          button: true,
                          child: InkWell(
                            key: const Key('invite.show_qr'),
                            onTap: showQr,
                            child: Text(
                              'invite_show_qr'.i18n,
                              style: helperStyle.copyWith(
                                color: context.textLink,
                                decoration: TextDecoration.underline,
                                decorationColor: context.textLink,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                // A claimed invite has no link left to share. If the
                // approval dialog was dismissed undecided, this reopens it.
                if (claimed)
                  PrimaryButton(
                    key: const Key('invite.compare'),
                    label: 'invite_compare_codes'.i18n,
                    onPressed: () async {
                      // The app-wide prompt need not open it again after
                      // Back leaves it undecided.
                      notifier.markApprovalPrompted(invite.id);
                      final f = showApproveHelperDialog(context, ref, invite);
                      approving.value = f;
                      try {
                        await f;
                      } finally {
                        if (approving.value == f) approving.value = null;
                      }
                    },
                  )
                else
                  KeyedSubtree(
                    key: const Key('invite.share'),
                    child: Builder(
                      builder: (buttonContext) => PrimaryButton(
                        label: 'invite_share_button'.i18n,
                        icon: AppImagePaths.share,
                        onPressed: () => share(buttonContext),
                      ),
                    ),
                  ),
                if (pending) ...[
                  const SizedBox(height: 12),
                  Row(
                    key: const Key('invite.waiting'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sync, size: 20, color: context.textSecondary),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'invite_waiting'.i18n,
                          style: textTheme.bodyMedium!.copyWith(
                            color: context.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: defaultSize),
          InfoRow(
            key: const Key('invite.trust_warning'),
            backgroundColor: context.bgPromo,
            imagePath: AppImagePaths.warning,
            text: 'invite_trust_warning'.i18n,
            textStyle: textTheme.bodySmall!.copyWith(
              color: context.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The invite's QR code, for a friend who is with the user to scan in
/// Lantern instead of opening the link.
Future<void> showInviteQrDialog(BuildContext context, String link) =>
    AppDialog.show(
      context: context,
      centered: true,
      scrollable: true,
      backgroundColor: context.bgSurface,
      title: 'invite_qr_title'.i18n,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          // A painter, not QrImageView: the dialog measures its content's
          // intrinsic width, which QrImageView's LayoutBuilder cannot give.
          Container(
            key: const Key('invite.qr'),
            width: 160,
            height: 160,
            color: Colors.white,
            padding: const EdgeInsets.all(10),
            child: CustomPaint(
              painter: QrPainter(data: link, version: QrVersions.auto),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'invite_qr_hint'.i18n,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.textSecondary),
          ),
        ],
      ),
      primaryLabel: 'done'.i18n,
    );
