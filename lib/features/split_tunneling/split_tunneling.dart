import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/split_tunnel_state.dart';
import 'package:lantern/core/widgets/section_label.dart';
import 'package:lantern/core/widgets/split_tunneling_tile.dart';
import 'package:lantern/core/widgets/switch_button.dart';
import 'package:lantern/features/split_tunneling/provider/split_tunnel_notifier.dart';

@RoutePage(name: 'SplitTunneling')
class SplitTunneling extends HookConsumerWidget {
  const SplitTunneling({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(splitTunnelProvider);
    final snapshot = current.value;
    final busy = useState(false);
    final notifier = ref.read(splitTunnelProvider.notifier);

    Future<void> apply(Future<Failure?> Function() action) async {
      if (busy.value) return;
      busy.value = true;
      final failure = await action();
      if (!context.mounted) return;
      busy.value = false;
      if (failure != null) {
        context.showSnackBarError(failure.localizedErrorMessage);
      }
    }

    Future<void> switchMode(SplitTunnelPolicy policy) async {
      if (snapshot == null || snapshot.policy == policy) return;
      await apply(() async {
        final confirmed = await confirmSplitTunnelPolicy(context, policy);
        if (!confirmed || !context.mounted) return null;
        return notifier.switchPolicy(policy);
      });
    }

    return BaseScreen(
      title: 'split_tunneling'.i18n,
      body: ListView(
        key: const Key('split_tunneling.screen'),
        children: [
          SizedBox(height: defaultSize),
          if (snapshot == null)
            if (current.hasError)
              SplitTunnelLoadFailed(onRetry: notifier.refresh)
            else
              const Center(child: CircularProgressIndicator())
          else ...[
            AppCard(
              padding: EdgeInsets.zero,
              child: AppTile(
                label: 'split_tunneling'.i18n,
                subtitle: _Subtitle('split_tunnel_description'.i18n),
                onPressed: () =>
                    apply(() => notifier.setEnabled(!snapshot.enabled)),
                trailing: IgnorePointer(
                  ignoring: busy.value,
                  child: SwitchButton(
                    key: const Key('split_tunneling.enable_toggle'),
                    value: snapshot.enabled,
                    onChanged: (enabled) =>
                        apply(() => notifier.setEnabled(enabled)),
                    activeColor: AppColors.green5,
                  ),
                ),
              ),
            ),
            SizedBox(height: defaultSize),
            SectionLabel('split_tunnel_mode'.i18n),
            const SizedBox(height: 4),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final policy in SplitTunnelPolicy.values) ...[
                    if (policy != SplitTunnelPolicy.values.first)
                      DividerSpace(),
                    AppTile(
                      tileKey: Key('split_tunneling.mode.${policy.wireValue}'),
                      enabled: !busy.value,
                      label: policy.labelKey.i18n,
                      subtitle: _Subtitle(
                        (policy == SplitTunnelPolicy.bypass
                                ? 'split_tunnel_bypass_description'
                                : 'split_tunnel_include_description')
                            .i18n,
                      ),
                      icon: Icon(
                        snapshot.policy == policy
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
            if (snapshot.enabled) ...[
              SizedBox(height: defaultSize),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    SplitTunnelingTile(
                      tileKey: const Key('split_tunneling.apps_tile'),
                      icon: AppImagePaths.keypad,
                      label: 'apps'.i18n,
                      actionText: _count(
                        snapshot.appCount,
                        'split_tunnel_app_count_one',
                        'split_tunnel_app_count',
                      ),
                      onPressed: () => appRouter.push(AppsSplitTunneling()),
                    ),
                    DividerSpace(),
                    SplitTunnelingTile(
                      tileKey: const Key('split_tunneling.websites_tile'),
                      icon: AppImagePaths.world,
                      label: 'websites'.i18n,
                      actionText: _count(
                        snapshot.websiteCount,
                        'split_tunnel_site_count_one',
                        'split_tunnel_site_count',
                      ),
                      onPressed: () => appRouter.push(WebsiteSplitTunneling()),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

Future<bool> confirmSplitTunnelPolicy(
  BuildContext context,
  SplitTunnelPolicy policy,
) async {
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
          (policy == SplitTunnelPolicy.includeOnly
                  ? 'split_tunnel_switch_include'
                  : 'split_tunnel_switch_bypass')
              .i18n,
          style: Theme.of(context).textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          (policy == SplitTunnelPolicy.includeOnly
                  ? 'split_tunnel_switch_include_body'
                  : 'split_tunnel_switch_bypass_body')
              .i18n,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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

String _count(int count, String one, String other) =>
    count == 1 ? one.i18n : other.i18n.fill([count]);

class _Subtitle extends StatelessWidget {
  const _Subtitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelMedium!.copyWith(
        color: context.textTertiary,
        letterSpacing: 0,
      ),
    );
  }
}

class SplitTunnelLoadFailed extends StatelessWidget {
  const SplitTunnelLoadFailed({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('split_tunnel_load_failed'.i18n),
        AppTextButton(label: 'retry'.i18n, onPressed: onRetry),
      ],
    );
  }
}
