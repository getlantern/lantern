import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/helpers/helper_errors.dart';
import 'package:lantern/features/helpers/models/helpers_view.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';

/// Shows the matching code of a claimed invite in a modal dialog, and lets
/// the inviter approve or reject the person who claimed it. Tapping outside
/// does not close it. Rejecting burns the invite: its link no longer works.
/// Completes with true once the engine accepted a decision.
Future<bool> showApproveHelperDialog(
  BuildContext context,
  HelperInviteView invite,
) async {
  // Read once: the notifier is keepAlive and outlives this dialog.
  final notifier = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(helpersProvider.notifier);
  final navigator = Navigator.of(context, rootNavigator: true);
  final textTheme = Theme.of(context).textTheme;
  final name = invite.volunteerName.isEmpty
      ? 'helper_unnamed'.i18n
      : invite.volunteerName;
  var decided = false;
  var busy = false;
  // Back can close the dialog while a decision is in flight; popping then
  // would close whatever is under it.
  var open = true;
  Future<void>? inflight;

  Future<void> decide(bool approve) async {
    if (busy) return;
    busy = true;
    final r = await notifier.decide(invite.id, approve: approve);
    busy = false;
    if (r.ok) {
      decided = true;
      if (open) navigator.pop();
      return;
    }
    if (context.mounted) context.showSnackBarError(helperErrorText(r.error!));
    if (r.error == 'no_pending_claim') {
      // Decided elsewhere, or an approval whose answer was lost: re-read,
      // and close, since there is nothing left to decide here.
      if (open) navigator.pop();
      await notifier.refresh();
    }
  }

  await AppDialog.show(
    context: context,
    centered: true,
    header: const Icon(Icons.check_circle_outline, size: 40),
    title: 'approve_title'.i18n.fill([name]),
    body: 'approve_body'.i18n.fill([name]),
    content: Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Semantics(
        label: spokenCode(invite.code),
        excludeSemantics: true,
        child: Text(
          invite.code,
          key: const Key('approve.code'),
          textAlign: TextAlign.center,
          style: textTheme.displayMedium,
        ),
      ),
    ),
    primaryLabel: 'approve_codes_match'.i18n,
    dismissOnPrimary: false,
    onPrimaryPressed: () {
      if (!busy) inflight = decide(true);
    },
    secondaryLabel: 'approve_reject'.i18n,
    dismissOnSecondary: false,
    onSecondaryPressed: () {
      if (!busy) inflight = decide(false);
    },
  );
  open = false;
  // Closed by Back mid-decision: answer with how the decision went.
  await inflight;
  return decided;
}

/// Spells a matching code digit by digit, so a screen reader does not read
/// "2562" as a number.
String spokenCode(String code) => code.split('').join(' ');

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
