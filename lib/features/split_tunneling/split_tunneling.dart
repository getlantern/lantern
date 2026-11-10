import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/split_tunnel_state.dart';
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
                subtitle: Text('split_tunnel_description'.i18n),
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
            Text(
              'split_tunnel_mode'.i18n,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final policy in SplitTunnelPolicy.values)
                    ListTile(
                      key: Key('split_tunneling.mode.${policy.wireValue}'),
                      enabled: !busy.value,
                      title: Text(policy.labelKey.i18n),
                      subtitle: Text(
                        (policy == SplitTunnelPolicy.bypass
                                ? 'split_tunnel_bypass_description'
                                : 'split_tunnel_include_description')
                            .i18n,
                      ),
                      leading: Icon(
                        snapshot.policy == policy
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                      ),
                      onTap: () => switchMode(policy),
                    ),
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
                      actionText: 'split_tunnel_added'.i18n.fill([
                        snapshot.appCount,
                      ]),
                      onPressed: () => appRouter.push(AppsSplitTunneling()),
                    ),
                    DividerSpace(),
                    SplitTunnelingTile(
                      tileKey: const Key('split_tunneling.websites_tile'),
                      icon: AppImagePaths.world,
                      label: 'websites'.i18n,
                      actionText: 'split_tunnel_added'.i18n.fill([
                        snapshot.websiteCount,
                      ]),
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
        Text(
          (policy == SplitTunnelPolicy.includeOnly
                  ? 'split_tunnel_switch_include'
                  : 'split_tunnel_switch_bypass')
              .i18n,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        Text(
          (policy == SplitTunnelPolicy.includeOnly
                  ? 'split_tunnel_switch_include_body'
                  : 'split_tunnel_switch_bypass_body')
              .i18n,
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
