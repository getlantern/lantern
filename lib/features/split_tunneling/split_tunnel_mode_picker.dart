import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/split_tunnel_state.dart';
import 'package:lantern/core/widgets/section_label.dart';
import 'package:lantern/features/split_tunneling/provider/split_tunnel_notifier.dart';

class SplitTunnelModePicker extends HookConsumerWidget {
  const SplitTunnelModePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(splitTunnelProvider).value?.policy;
    final busy = useState(false);

    Future<void> switchMode(SplitTunnelPolicy policy) async {
      if (busy.value || current == null || current == policy) return;
      busy.value = true;
      Failure? failure;
      if (await _confirmSwitch(context, policy) && context.mounted) {
        failure = await ref
            .read(splitTunnelProvider.notifier)
            .switchPolicy(policy);
      }
      if (!context.mounted) return;
      busy.value = false;
      if (failure != null) {
        context.showSnackBarError(failure.localizedErrorMessage);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel('split_tunnel_mode'.i18n),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final policy in SplitTunnelPolicy.values) ...[
                if (policy != SplitTunnelPolicy.values.first) DividerSpace(),
                AppTile(
                  tileKey: Key('split_tunneling.mode.${policy.wireValue}'),
                  enabled: !busy.value,
                  label: policy.labelKey.i18n,
                  subtitle: Text(
                    policy.descriptionKey.i18n,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: context.textTertiary,
                    ),
                  ),
                  icon: Icon(
                    current == policy
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: context.textPrimary,
                  ),
                  onPressed: () => switchMode(policy),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

Future<bool> _confirmSwitch(
  BuildContext context,
  SplitTunnelPolicy policy,
) async {
  final title = switch (policy) {
    SplitTunnelPolicy.bypass => 'split_tunnel_switch_bypass',
    SplitTunnelPolicy.includeOnly => 'split_tunnel_switch_include',
  };
  final textTheme = Theme.of(context).textTheme;
  var confirmed = false;
  await AppDialog.customDialog(
    context: context,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: size24),
        Center(child: AppImage(path: AppImagePaths.warning, height: 45)),
        SizedBox(height: size24),
        Text(
          title.i18n,
          style: textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          '${title}_body'.i18n,
          style: textTheme.bodyMedium?.copyWith(
            color: context.textSecondary,
            height: 23 / 16,
          ),
        ),
      ],
    ),
    action: [
      PrimaryButton(
        key: const Key('split_tunneling.mode.cancel'),
        label: 'cancel'.i18n,
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
      ),
      SecondaryButton(
        key: const Key('split_tunneling.mode.confirm'),
        label: 'split_tunnel_switch'.i18n,
        onPressed: () {
          confirmed = true;
          Navigator.of(context, rootNavigator: true).pop();
        },
      ),
    ],
  );
  return confirmed;
}
