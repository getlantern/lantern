import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/helpers/helper_errors.dart';
import 'package:lantern/features/helpers/models/helpers_view.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';

/// Shows the matching code of a claimed invite and lets the inviter approve
/// or reject the person who claimed it. Completes with true once the engine
/// accepted a decision.
Future<bool> showApproveHelperSheet(
  BuildContext context,
  HelperInviteView invite,
) async {
  final decided = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ApproveHelperSheet(invite: invite),
  );
  return decided ?? false;
}

/// Spells a matching code digit by digit, so a screen reader does not read
/// "2562" as a number.
String spokenCode(String code) => code.split('').join(' ');

class ApproveHelperSheet extends HookConsumerWidget {
  const ApproveHelperSheet({super.key, required this.invite});

  final HelperInviteView invite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = useState(false);
    final textTheme = Theme.of(context).textTheme;
    final name = invite.volunteerName.isEmpty
        ? 'helper_unnamed'.i18n
        : invite.volunteerName;

    Future<void> decide(bool approve) async {
      // Read once: the notifier outlives this sheet; its ref may not.
      final notifier = ref.read(helpersProvider.notifier);
      busy.value = true;
      final r = await notifier.decide(invite.id, approve: approve);
      if (!context.mounted) return;
      busy.value = false;
      if (r.ok) {
        await Navigator.of(context).maybePop(true);
        return;
      }
      context.showSnackBarError(helperErrorText(r.error!));
      if (r.error == 'no_pending_claim') {
        // Decided elsewhere, or an approval whose answer was lost: re-read.
        await notifier.refresh();
      }
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(defaultSize),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('invite_claimed_title'.i18n, style: textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(
              'approve_code_intro'.i18n.fill([name]),
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'approve_code_label'.i18n,
              style: textTheme.labelMedium,
              textAlign: TextAlign.center,
            ),
            Semantics(
              label: spokenCode(invite.code),
              excludeSemantics: true,
              child: Text(
                invite.code,
                key: const Key('approve.code'),
                textAlign: TextAlign.center,
                style: textTheme.displayMedium?.copyWith(letterSpacing: 8),
              ),
            ),
            const SizedBox(height: 16),
            KeyedSubtree(
              key: const Key('approve.yes'),
              child: PrimaryButton(
                label: 'approve_button'.i18n,
                enabled: !busy.value,
                onPressed: () => decide(true),
              ),
            ),
            const SizedBox(height: 8),
            KeyedSubtree(
              key: const Key('approve.no'),
              child: SecondaryButton(
                label: 'reject_button'.i18n,
                enabled: !busy.value,
                onPressed: () => decide(false),
              ),
            ),
            const SizedBox(height: 8),
            Text('reject_explainer'.i18n, style: textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Asks for the name the other person knows this user by, or, given another
/// [label], some other name, such as a friend's nickname on this device.
/// Returns null when cancelled or left empty; with [allowEmpty], a name left
/// empty returns '' instead.
Future<String?> askHelperName(
  BuildContext context, {
  required String initial,
  required String title,
  String? label,
  bool allowEmpty = false,
}) async {
  var current = initial;
  String? result;
  final invalid = ValueNotifier(false);
  final navigator = Navigator.of(context, rootNavigator: true);
  await AppDialog.show(
    context: context,
    title: title,
    content: _HelperNameField(
      initial: initial,
      label: label,
      invalid: invalid,
      onChanged: (v) {
        current = v;
        invalid.value = false;
      },
    ),
    primaryLabel: 'continue'.i18n,
    // AppDialog runs a dismissing primary callback 400 ms after the pop, too
    // late for show()'s future. Record the name first, then dismiss.
    dismissOnPrimary: false,
    onPrimaryPressed: () {
      final name = current.trim();
      if (name.isEmpty && !allowEmpty) {
        // Keep the dialog open and say why, rather than closing silently.
        invalid.value = true;
        return;
      }
      result = name;
      navigator.pop();
    },
    secondaryLabel: 'cancel'.i18n,
  );
  final name = result;
  if (name == null) return null;
  return name.isEmpty && !allowEmpty ? null : name;
}

/// The name field inside askHelperName's dialog. It owns its controller,
/// which the hook disposes when the dialog's route is gone, after its exit
/// animation, not when show() returns.
class _HelperNameField extends HookWidget {
  const _HelperNameField({
    required this.initial,
    this.label,
    required this.invalid,
    required this.onChanged,
  });

  final String initial;
  final String? label;
  final ValueListenable<bool> invalid;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController(text: initial);
    final showError = useValueListenable(invalid);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: controller,
          label: label ?? 'helpers_your_name_label'.i18n,
          hintText: 'helpers_your_name_hint'.i18n,
          maxLength: 60,
          autofocus: true,
          onChanged: onChanged,
        ),
        if (showError)
          Text(
            helperErrorText('bad_name'),
            key: const Key('helpers.name.error'),
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
      ],
    );
  }
}
