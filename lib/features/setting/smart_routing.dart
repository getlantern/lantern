import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/info_row.dart';
import 'package:lantern/features/home/provider/radiance_settings_providers.dart';

@RoutePage(name: 'SmartRouting')
class SmartRouting extends HookConsumerWidget {
  const SmartRouting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final selected = ref.watch(
      radianceSettingsProvider.select((s) => s.routingMode),
    );

    Future<void> select(RoutingMode mode) async {
      final result = await ref
          .read(radianceSettingsProvider.notifier)
          .setRoutingMode(mode);
      result.fold(
        (failure) {
          context.showSnackBar('failed_to_update_routing_mode'.i18n);
        },
        (_) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) appRouter.pop();
          });
        },
      );
    }

    return BaseScreen(
      title: 'routing_mode'.i18n,
      body: Column(
        children: [
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                AppTile(
                  onPressed: () => select(RoutingMode.smart),
                  icon: AppRadioButton<RoutingMode>(
                    groupValue: selected,
                    value: RoutingMode.smart,
                  ),
                  label: 'smart_routing'.i18n,
                  subtitle: Text(
                    'region_optimized_routing'.i18n,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelMedium!.copyWith(
                      color: context.textTertiary,
                      letterSpacing: 0.0,
                    ),
                  ),
                ),
                DividerSpace(),
                AppTile(
                  onPressed: () => select(RoutingMode.full),
                  icon: AppRadioButton<RoutingMode>(
                    groupValue: selected,
                    value: RoutingMode.full,
                  ),
                  label: 'full_tunnel'.i18n,
                  subtitle: Text(
                    'all_traffic_through_vpn'.i18n,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelMedium!.copyWith(
                      color: context.textTertiary,
                      letterSpacing: 0.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: size24),
          InfoRow(text: 'smart_routing_description'.i18n),
        ],
      ),
    );
  }
}
