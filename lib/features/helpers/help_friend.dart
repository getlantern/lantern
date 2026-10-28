import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/action_mode/provider/share_notifier.dart';
import 'package:lantern/features/helpers/approve_helper_sheet.dart'
    show spokenCode;
import 'package:lantern/features/helpers/helper_errors.dart';
import 'package:lantern/features/helpers/helping_section.dart'
    show HelperKeystoreResetNotice;
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';

/// A volunteer accepts an invite: from a link that opened the app, a scanned
/// QR code, or a pasted link. It shows the code to read to the friend, then
/// waits for approval. The link is a secret: it is never logged or shown.
@RoutePage(name: 'HelpFriend')
class HelpFriend extends HookConsumerWidget {
  const HelpFriend({super.key, this.fromLink = false});

  /// Whether a deep link opened this screen. Its secret is held by the
  /// notifier (holdLink), never passed in route arguments.
  final bool fromLink;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final helpers = ref.watch(helpersProvider);
    // Held rather than read after an await: this screen may be gone by then.
    final notifier = ref.read(helpersProvider.notifier);
    final share = ref.read(shareProvider.notifier);
    final link = useMemoized(() => fromLink ? notifier.takeLink() : null);
    final linkCtl = useTextEditingController(text: link ?? '');
    final nameCtl = useTextEditingController(text: helpers.view.myName);
    final code = useState<String?>(null);
    final approvalsAtClaim = useState<int?>(null);
    final error = useState<String?>(null);
    final busy = useState(false);

    useEffect(() {
      // refreshIfUsed, not refresh: opening this screen must not touch the
      // keystore (Plan rules). The claim unlocks it.
      unawaited(notifier.refreshIfUsed());
      return null;
    }, const []);

    if (!AppBuildInfo.enableHelperInvites) {
      return BaseScreen(
        title: 'help_friend_title'.i18n,
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
      final r = await notifier.claim(linkCtl.text, nameCtl.text);
      if (!context.mounted) return;
      busy.value = false;
      if (!r.ok) {
        error.value = r.error;
        return;
      }
      approvalsAtClaim.value = ref.read(helpersProvider).helpingApprovals;
      code.value = r.data['code'] as String?;
    }

    final approved =
        approvalsAtClaim.value != null &&
        helpers.helpingApprovals > approvalsAtClaim.value!;

    final Widget body;
    if (approved) {
      final helping = helpers.view.helping;
      final name = helping.isEmpty || helping.last.name.isEmpty
          ? 'helping_unnamed'.i18n
          : helping.last.name;
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
    } else if (code.value != null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: defaultSize),
          Text('help_friend_code_title'.i18n, style: textTheme.titleLarge),
          const SizedBox(height: 12),
          Semantics(
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
          Text('help_friend_code_body'.i18n, style: textTheme.bodyMedium),
          const SizedBox(height: 24),
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text('help_friend_waiting'.i18n)),
            ],
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
      body = ListView(
        padding: const EdgeInsets.symmetric(vertical: defaultSize),
        children: [
          if (helpers.keystoreReset) ...[
            HelperKeystoreResetNotice(notifier: notifier),
            const SizedBox(height: defaultSize),
          ],
          Text('help_friend_intro'.i18n, style: textTheme.bodyMedium),
          const SizedBox(height: defaultSize),
          if (link == null) ...[
            AppTextField(
              fieldKey: const Key('help_friend.link'),
              controller: linkCtl,
              label: 'help_friend_link_label'.i18n,
              hintText: 'help_friend_paste'.i18n,
            ),
            if (AppBuildInfo.enableQrScanner && PlatformUtils.isMobile)
              AppTextButton(
                label: 'help_friend_scan'.i18n,
                onPressed: () async {
                  final scanned = await appRouter.push(QrCodeScanner());
                  if (scanned is String) linkCtl.text = scanned;
                },
              ),
            const SizedBox(height: defaultSize),
          ],
          AppTextField(
            fieldKey: const Key('help_friend.name'),
            controller: nameCtl,
            label: 'helpers_your_name_label'.i18n,
            hintText: 'helpers_your_name_hint'.i18n,
            maxLength: 60,
          ),
          const SizedBox(height: 8),
          Text('help_friend_sharing_note'.i18n, style: textTheme.bodySmall),
          if (error.value != null) ...[
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
              label: 'help_friend_accept'.i18n,
              enabled: !busy.value,
              onPressed: submit,
            ),
          ),
        ],
      );
    }
    return BaseScreen(title: 'help_friend_title'.i18n, body: body);
  }
}
