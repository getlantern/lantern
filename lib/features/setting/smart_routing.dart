import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/info_row.dart';
import 'package:lantern/core/widgets/switch_button.dart';
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
    final proxyless = ref.watch(
      radianceSettingsProvider.select((s) => s.proxyless),
    );

    Future<void> setProxyless(bool value) async {
      final result = await ref
          .read(radianceSettingsProvider.notifier)
          .setProxyless(value);
      if (!context.mounted) return;
      result.fold(
        (_) => context.showSnackBar('failed_to_update_proxyless'.i18n),
        (_) {},
      );
    }

    // The screen stays open: Smart Routing's options show or hide under
    // the radios as the mode changes. A mode tapped while another's write
    // runs is compared with that one, so tapping back reverses it.
    Future<void> select(RoutingMode mode) async {
      final notifier = ref.read(radianceSettingsProvider.notifier);
      if (mode == notifier.requestedRoutingMode) return;
      final result = await notifier.setRoutingMode(mode);
      if (!context.mounted) return;
      result.fold(
        (_) => context.showSnackBar('failed_to_update_routing_mode'.i18n),
        (_) {},
      );
    }

    return BaseScreen(
      title: 'routing_mode'.i18n,
      // Scrolls, so the explanation stays reachable on short screens and
      // with large text.
      body: ListView(
        padding: EdgeInsets.zero,
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
          // Smart Routing's options, and the note explaining both. Full
          // Tunnel sends everything through the VPN, so there is nothing to
          // try directly and nothing to explain: only the two radios.
          if (selected == RoutingMode.smart) ...[
            SizedBox(height: size24),
            Padding(
              padding: const EdgeInsets.only(left: defaultSize),
              child: Text(
                'smart_routing_options'.i18n,
                key: const Key('smart_routing.options'),
                style: textTheme.labelLarge!.copyWith(
                  color: context.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 4.0),
            AppCard(
              key: const Key('smart_routing.proxyless_card'),
              padding: EdgeInsets.zero,
              child: AppTile(
                label: 'proxyless'.i18n,
                subtitle: Text(
                  'proxyless_reaches_blocked'.i18n,
                  style: textTheme.labelMedium!.copyWith(
                    color: context.textTertiary,
                    letterSpacing: 0.0,
                  ),
                ),
                trailing: SwitchButton(
                  key: const Key('smart_routing.proxyless'),
                  value: proxyless,
                  onChanged: setProxyless,
                ),
                onPressed: () => setProxyless(!proxyless),
              ),
            ),
            SizedBox(height: defaultSize),
            // The screen's own background, with only its outline, so it
            // reads as a note rather than another card.
            InfoRow(
              key: const Key('smart_routing.note'),
              backgroundColor: context.bgSurface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              text: 'smart_routing_direct_description'.i18n,
            ),
          ],
        ],
      ),
    );
  }
}
