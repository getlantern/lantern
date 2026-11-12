import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
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
                subtitle: Text(
                  'split_tunnel_description'.i18n,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: context.textTertiary,
                  ),
                ),
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
                      subtitle: snapshot.policy.appsLabelKey.i18n,
                      actionText: _count(
                        snapshot.appCount,
                        'split_tunnel_app_count_one',
                        'split_tunnel_app_count',
                      ),
                      onPressed: () =>
                          appRouter.push(const AppsSplitTunneling()),
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
                      onPressed: () =>
                          appRouter.push(const WebsiteSplitTunneling()),
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

String _count(int count, String one, String other) =>
    count == 1 ? one.i18n : other.i18n.fill([count]);

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
