import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/helpers/helper_errors.dart';
import 'package:lantern/features/helpers/models/helpers_view.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';

/// Shows the matching code of a claimed invite and lets the inviter approve
/// or reject the person who claimed it.
Future<void> showApproveHelperSheet(
  BuildContext context,
  HelperInviteView invite,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ApproveHelperSheet(invite: invite),
  );
}

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
      busy.value = true;
      final r = await ref
          .read(helpersProvider.notifier)
          .decide(invite.id, approve: approve);
      if (!context.mounted) return;
      busy.value = false;
      if (r.ok) {
        await Navigator.of(context).maybePop();
        return;
      }
      context.showSnackBarError(helperErrorText(r.error!));
      if (r.error == 'no_pending_claim') {
        // Decided elsewhere, or an approval whose answer was lost: re-read.
        await ref.read(helpersProvider.notifier).refresh();
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
            Text(
              invite.code,
              key: const Key('approve.code'),
              textAlign: TextAlign.center,
              style: textTheme.displayMedium?.copyWith(letterSpacing: 8),
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

/// Asks for the name the other person knows this user by. Returns null when
/// cancelled or left empty.
Future<String?> askHelperName(
  BuildContext context, {
  required String initial,
  required String title,
}) async {
  var current = initial;
  String? result;
  final navigator = Navigator.of(context, rootNavigator: true);
  await AppDialog.show(
    context: context,
    title: title,
    content: _HelperNameField(initial: initial, onChanged: (v) => current = v),
    primaryLabel: 'continue'.i18n,
    // AppDialog runs a dismissing primary callback 400 ms after the pop, too
    // late for show()'s future. Record the name first, then dismiss.
    dismissOnPrimary: false,
    onPrimaryPressed: () {
      result = current.trim();
      navigator.pop();
    },
    secondaryLabel: 'cancel'.i18n,
  );
  final name = result;
  return (name == null || name.isEmpty) ? null : name;
}

/// The name field inside askHelperName's dialog. It owns its controller,
/// which the hook disposes when the dialog's route is gone, after its exit
/// animation, not when show() returns.
class _HelperNameField extends HookWidget {
  const _HelperNameField({required this.initial, required this.onChanged});

  final String initial;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController(text: initial);
    return AppTextField(
      controller: controller,
      label: 'helpers_your_name_label'.i18n,
      hintText: 'helpers_your_name_hint'.i18n,
      maxLength: 60,
      autofocus: true,
      onChanged: onChanged,
    );
  }
}
