import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/utils/deeplink_utils.dart';
import 'package:lantern/core/widgets/info_row.dart';
import 'package:lantern/features/action_mode/provider/share_notifier.dart';
import 'package:lantern/features/helpers/approve_helper_dialog.dart'
    show spokenCode;
import 'package:lantern/features/helpers/helper_errors.dart';
import 'package:lantern/features/helpers/helping_friends.dart'
    show HelperKeystoreResetNotice;
import 'package:lantern/features/helpers/models/helpers_view.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';

/// "Become a Personal Proxy": a volunteer accepts an invite, from a link that
/// opened the app (filled in), a scanned QR code, or a pasted link. It shows
/// the code to read to the friend, then waits for approval. The link is a
/// secret: it is never logged.
@RoutePage(name: 'HelpFriend')
class HelpFriend extends HookConsumerWidget {
  const HelpFriend({super.key, this.fromLink = false, this.newInvite = false});

  /// Whether a deep link opened this screen. Its secret is held by the
  /// notifier (holdLink), never passed in route arguments.
  final bool fromLink;

  /// Opened to add another friend ("Paste another invite link"): show the
  /// paste form even while an earlier claim waits, rather than its code.
  final bool newInvite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final helpers = ref.watch(helpersProvider);
    // Held rather than read after an await: this screen may be gone by then.
    final notifier = ref.read(helpersProvider.notifier);
    final share = ref.read(shareProvider.notifier);
    final link = useMemoized(() => fromLink ? notifier.takeLink() : null);
    final linkCtl = useTextEditingController(text: link ?? '');
    final linkText = useValueListenable(linkCtl).text;
    final nameCtl = useTextEditingController(text: helpers.view.myName);
    final code = useState<String?>(null);
    // This screen's own claim: its outcome, not anyone else's, ends the wait.
    final claimId = useRef<String?>(null);
    // To tell which new pairing came from this claim.
    final helpingAtClaim = useRef<Set<String>>(const {});
    // The view when the claim was answered. A claim missing from that same
    // view (its refresh failed) has not left yet; it may not have arrived.
    final viewAtClaim = useRef<HelpersView?>(null);
    final claimSeen = useRef(false);
    // Once settled, the outcome stays: a pairing ended later does not turn
    // "approved" into "no longer pending".
    final settled = useRef<_ClaimOutcome?>(null);
    final error = useState<String?>(null);
    final busy = useState(false);
    final resumed = useRef(false);

    useEffect(() {
      // refreshIfUsed, not refresh: opening this screen must not touch the
      // keystore (Plan rules). The claim unlocks it.
      unawaited(notifier.refreshIfUsed());
      return null;
    }, const []);

    useEffect(() {
      // Opened without a link while a claim waits (the volunteer backed out
      // of the code): show that code again, once. A provisional claim may
      // never have reached the inviter, and is retried by claiming its link
      // again; an expired one waits for nothing.
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final pending = helpers.view.waitingClaims(now);
      if (link != null ||
          newInvite ||
          resumed.value ||
          code.value != null ||
          busy.value ||
          pending.isEmpty) {
        return null;
      }
      resumed.value = true;
      final latest = pending.reduce(
        (a, b) => b.expiresUnix >= a.expiresUnix ? b : a,
      );
      claimId.value = latest.id;
      helpingAtClaim.value = {
        for (final p in helpers.view.helping) p.pairingId,
      };
      viewAtClaim.value = helpers.view;
      code.value = latest.code;
      return null;
    }, [helpers.view.claims]);

    if (!AppBuildInfo.enableHelperInvites) {
      return BaseScreen(
        title: 'become_personal_proxy'.i18n,
        body: Center(child: Text('helper_error_disabled'.i18n)),
      );
    }

    Future<void> submit() async {
      error.value = null;
      busy.value = true;
      final consented = await share.ensureConsent(context);
      if (!context.mounted) return;
      if (!consented) {
        busy.value = false;
        return;
      }
      final r = await notifier.claim(
        normalizeHelperInviteInput(linkCtl.text),
        nameCtl.text,
      );
      if (!context.mounted) return;
      busy.value = false;
      if (!r.ok) {
        error.value = r.error;
        return;
      }
      final claimed = r.data['code'];
      if (claimed is! String || claimed.isEmpty) {
        error.value = 'unavailable';
        return;
      }
      final now = ref.read(helpersProvider);
      claimId.value = r.data['claim_id'] as String?;
      helpingAtClaim.value = {for (final p in now.view.helping) p.pairingId};
      viewAtClaim.value = now.view;
      code.value = claimed;
    }

    final outcome = code.value == null
        ? _ClaimOutcome.waiting
        : settled.value ??
              _claimOutcome(
                helpers.view,
                claimId.value,
                helpingAtClaim.value,
                seen:
                    claimSeen.value ||
                    !identical(helpers.view, viewAtClaim.value),
              );
    if (claimId.value != null &&
        helpers.view.claims.any((c) => c.id == claimId.value)) {
      claimSeen.value = true;
    }
    if (outcome != _ClaimOutcome.waiting) settled.value = outcome;
    final approved = outcome == _ClaimOutcome.approved;

    final Widget body;
    if (approved) {
      final name = _approvedName(helpers, claimId.value, helpingAtClaim.value);
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: defaultSize),
          Text(
            'help_friend_approved'.i18n.fill([name]),
            key: const Key('help_friend.approved'),
            style: textTheme.titleLarge,
          ),
          const SizedBox(height: defaultSize),
          PrimaryButton(
            label: 'help_friend_done'.i18n,
            onPressed: () => appRouter.maybePop(),
          ),
        ],
      );
    } else if (outcome == _ClaimOutcome.gone) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: defaultSize),
          Text(
            'help_friend_no_longer_pending'.i18n,
            key: const Key('help_friend.gone'),
            style: textTheme.titleLarge,
          ),
          const SizedBox(height: defaultSize),
          PrimaryButton(
            label: 'help_friend_done'.i18n,
            onPressed: () => appRouter.maybePop(),
          ),
        ],
      );
    } else if (code.value != null) {
      body = ListView(
        padding: const EdgeInsets.symmetric(vertical: defaultSize),
        children: [
          AppCard(
            key: const Key('help_friend.waiting'),
            padding: const EdgeInsets.all(defaultSize),
            child: Column(
              children: [
                Text(
                  'help_friend_tell_code'.i18n,
                  textAlign: TextAlign.center,
                  style: textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                // Its own node: the card would merge it into one label.
                Semantics(
                  container: true,
                  label: spokenCode(code.value!),
                  excludeSemantics: true,
                  child: Text(
                    code.value!,
                    key: const Key('help_friend.code'),
                    textAlign: TextAlign.center,
                    style: textTheme.displayMedium?.copyWith(letterSpacing: 8),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'help_friend_code_check'.i18n,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium!.copyWith(
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'help_friend_waiting_approval'.i18n,
                        style: textTheme.labelMedium!.copyWith(
                          color: context.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: defaultSize),
          InfoRow(
            key: const Key('help_friend.code_note'),
            backgroundColor: context.bgPromo,
            imagePath: AppImagePaths.warning,
            text: 'help_friend_code_note'.i18n,
          ),
        ],
      );
    } else if (error.value == 'already_helping') {
      final helping = helpers.view.helping;
      // The engine says only that this link is one this device helps for;
      // with a single pairing, that is the one.
      final text = helping.length == 1 && helping.single.name.isNotEmpty
          ? 'help_friend_already_helping_named'.i18n.fill([helping.single.name])
          : 'help_friend_already_helping'.i18n;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: defaultSize),
          Icon(
            Icons.check_circle_outline,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            text,
            key: const Key('help_friend.already_helping'),
            style: textTheme.titleLarge,
          ),
          const SizedBox(height: defaultSize),
          PrimaryButton(
            label: 'help_friend_done'.i18n,
            onPressed: () => appRouter.maybePop(),
          ),
        ],
      );
    } else if (error.value == 'already_claimed') {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: defaultSize),
          Icon(
            Icons.warning_amber_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(
            'help_friend_already_claimed_title'.i18n,
            key: const Key('help_friend.already_claimed'),
            style: textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(
            'help_friend_already_claimed_body'.i18n,
            style: textTheme.bodyMedium,
          ),
        ],
      );
    } else {
      final linkValid = isHelperInviteInput(linkText);
      // A link that cannot be an invite, as typed, or as the engine refused.
      final String? linkError = _linkErrors.contains(error.value)
          ? helperErrorText(error.value!)
          : linkText.trim().isNotEmpty && !linkValid
          ? helperErrorText('bad_link')
          : null;
      final hintStyle = textTheme.labelMedium!.copyWith(
        color: context.textTertiary,
      );
      Widget below(String text, {Key? key, Color? color}) => Padding(
        padding: const EdgeInsets.only(left: 8, top: 4),
        child: Text(
          text,
          key: key,
          style: color == null ? hintStyle : hintStyle.copyWith(color: color),
        ),
      );
      body = ListView(
        padding: const EdgeInsets.symmetric(vertical: defaultSize),
        children: [
          if (helpers.keystoreReset) ...[
            HelperKeystoreResetNotice(notifier: notifier),
            const SizedBox(height: defaultSize),
          ],
          const _HelpingMeansCard(),
          const SizedBox(height: defaultSize),
          AppCard(
            key: const Key('help_friend.form'),
            padding: const EdgeInsets.all(defaultSize),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'help_friend_form_title'.i18n,
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: defaultSize),
                AppTextField(
                  fieldKey: const Key('help_friend.link'),
                  controller: linkCtl,
                  label: 'help_friend_link_label'.i18n,
                  hintText: 'help_friend_paste'.i18n,
                  prefixIcon: Icons.link,
                  autocorrect: false,
                  enableSuggestions: false,
                  enableIMEPersonalizedLearning: false,
                  onChanged: (_) {
                    if (_linkErrors.contains(error.value)) error.value = null;
                  },
                ),
                if (linkError != null)
                  below(
                    linkError,
                    key: const Key('help_friend.link_error'),
                    color: Theme.of(context).colorScheme.error,
                  )
                else
                  below('help_friend_link_hint'.i18n),
                if (AppBuildInfo.enableQrScanner && PlatformUtils.isMobile)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: AppTextButton(
                      key: const Key('help_friend.scan'),
                      label: 'help_friend_scan'.i18n,
                      onPressed: () async {
                        final scanned = await appRouter.push(QrCodeScanner());
                        if (scanned is String) linkCtl.text = scanned;
                      },
                    ),
                  ),
                const SizedBox(height: defaultSize),
                AppTextField(
                  fieldKey: const Key('help_friend.name'),
                  controller: nameCtl,
                  label: 'help_friend_name_label'.i18n,
                  hintText: 'helpers_your_name_hint'.i18n,
                  prefixIcon: Icons.person_outline,
                  maxLength: 60,
                ),
                below('help_friend_name_hint'.i18n),
                if (error.value != null && linkError == null) ...[
                  const SizedBox(height: 8),
                  Text(
                    helperErrorText(error.value!),
                    key: const Key('help_friend.error'),
                    style: textTheme.bodyMedium!.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: defaultSize),
                KeyedSubtree(
                  key: const Key('help_friend.accept'),
                  child: PrimaryButton(
                    label: 'help_friend_become'.i18n,
                    enabled: !busy.value && linkValid,
                    onPressed: submit,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return BaseScreen(title: 'become_personal_proxy'.i18n, body: body);
  }
}

/// What being a Personal Proxy involves, before the volunteer accepts: what
/// the friend can see, and that it can stop.
class _HelpingMeansCard extends StatelessWidget {
  const _HelpingMeansCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    Widget row(Widget icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: textTheme.bodyMedium!.copyWith(
                color: context.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
    return AppCard(
      key: const Key('help_friend.means'),
      padding: const EdgeInsets.all(defaultSize),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('become_means_title'.i18n, style: textTheme.titleMedium),
          row(
            const AppImage(path: AppImagePaths.lock, width: 24, height: 24),
            'become_means_traffic'.i18n,
          ),
          row(
            const AppImage(path: AppImagePaths.eye, width: 24, height: 24),
            'become_means_seen'.i18n,
          ),
          // The app's delete.svg is an alert mark; this is the trash can.
          row(
            const Icon(Icons.delete_outline, size: 24),
            'become_means_remove'.i18n,
          ),
        ],
      ),
    );
  }
}

/// Engine errors about the link itself, shown on the link field.
const _linkErrors = {'bad_link', 'own_invite'};

enum _ClaimOutcome { waiting, approved, gone }

/// What became of this screen's claim. While it is in the view it waits,
/// whatever other claims do. Once it has left, a new pairing means it was
/// approved; none means it was rejected, expired or pruned. [seen] says the
/// view reflects the claim at all: a claim whose refresh failed is missing
/// from the view it was answered with, and has not left.
_ClaimOutcome _claimOutcome(
  HelpersView view,
  String? claimId,
  Set<String> helpingAtClaim, {
  required bool seen,
}) {
  if (claimId != null && view.claims.any((c) => c.id == claimId)) {
    return _ClaimOutcome.waiting;
  }
  if (view.helping.any((p) => !helpingAtClaim.contains(p.pairingId))) {
    return _ClaimOutcome.approved;
  }
  // Without its ID, nothing says the claim is gone.
  return claimId != null && seen ? _ClaimOutcome.gone : _ClaimOutcome.waiting;
}

/// The name of the pairing this claim became, or the generic wording when it
/// cannot be told apart. The engine drops a claim when its key opens the new
/// pairing's name, so the claim must be gone and exactly one pairing new.
String _approvedName(
  HelpersState helpers,
  String? claimId,
  Set<String> helpingAtClaim,
) {
  final view = helpers.view;
  final stillPending =
      claimId == null || view.claims.any((c) => c.id == claimId);
  final added = view.helping
      .where((p) => !helpingAtClaim.contains(p.pairingId))
      .toList();
  if (stillPending || added.length != 1 || added.single.name.isEmpty) {
    return 'helping_unnamed'.i18n;
  }
  return added.single.name;
}
