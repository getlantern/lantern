import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/widgets/switch_button.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

import '../../core/common/common.dart';
import '../action_mode/auto_enable_mode.dart';

/// Action Mode settings: auto-enable, hide the tab, and (desktop/Android)
/// the manual port forward for routers without UPnP.
@RoutePage(name: 'ActionModeSetting')
class ActionModeSetting extends ConsumerWidget {
  const ActionModeSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(
      appSettingProvider.select((s) => s.unboundedHidden),
    );
    final notifier = ref.read(appSettingProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    return BaseScreen(
      title: 'unbounded_settings_title'.i18n,
      body: ListView(
        children: [
          const SizedBox(height: 16),
          const ActionModeAutoEnable(),
          const SizedBox(height: 16),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                AppTile(
                  label: 'hide_unbounded'.i18n,
                  subtitle: Text(
                    'hide_unbounded_subtitle'.i18n,
                    style: textTheme.labelMedium!.copyWith(
                      color: context.textTertiary,
                      letterSpacing: 0.0,
                    ),
                  ),
                  icon: Icons.visibility_off_outlined,
                  trailing: SwitchButton(
                    value: hidden,
                    onChanged: notifier.setUnboundedHidden,
                  ),
                  onPressed: () => notifier.setUnboundedHidden(!hidden),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (!PlatformUtils.isIOS) const _AdvancedCard(),
        ],
      ),
    );
  }
}

/// Manual port forward, for routers without UPnP. Lives in Unbounded
/// Settings; takes effect the next time sharing is turned on.
class _AdvancedCard extends HookConsumerWidget {
  const _AdvancedCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Theme(
        // The container border already outlines the section.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text('smc_advanced'.i18n, style: textTheme.labelLarge),
          subtitle: Text(
            'smc_advanced_subtitle'.i18n,
            style: textTheme.labelSmall,
          ),
          children: const [_ManualPortField()],
        ),
      ),
    );
  }
}

class _ManualPortField extends HookConsumerWidget {
  const _ManualPortField();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final controller = useTextEditingController();
    final loaded = useState(false);
    final saving = useState(false);
    final lastSaved = useState<int?>(null);

    // One-shot load; the guard keeps a late result from writing to disposed
    // controllers.
    useEffect(() {
      var disposed = false;
      Future.microtask(() async {
        final result =
            await ref.read(lanternServiceProvider).getPeerManualPort();
        if (disposed) return;
        result.fold((_) => null, (port) {
          if (port > 0) controller.text = port.toString();
          lastSaved.value = port;
        });
        loaded.value = true;
      });
      return () => disposed = true;
    }, const []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'smc_manual_port'.i18n,
          style: textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'smc_manual_port_description'.i18n,
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: false,
                  signed: false,
                ),
                decoration: InputDecoration(
                  labelText: 'smc_manual_port_label'.i18n,
                  hintText: 'smc_manual_port_hint'.i18n,
                  border: const OutlineInputBorder(),
                  isDense: true,
                  enabled: loaded.value && !saving.value,
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: (loaded.value && !saving.value)
                  ? () => _save(ref, context, controller, saving, lastSaved)
                  : null,
              child: saving.value
                  ? const SizedBox(
                      height: 16, width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('smc_manual_port_save'.i18n),
            ),
          ],
        ),
        if (lastSaved.value != null && lastSaved.value! > 0) ...[
          const SizedBox(height: 8),
          Text(
            'smc_manual_port_currently_set'.i18n.fill([lastSaved.value!]),
            style: textTheme.bodySmall?.copyWith(
              color: Theme.of(context).hintColor,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _save(
    WidgetRef ref,
    BuildContext context,
    TextEditingController controller,
    ValueNotifier<bool> saving,
    ValueNotifier<int?> lastSaved,
  ) async {
    saving.value = true;
    try {
      final raw = controller.text.trim();
      int port = 0;
      if (raw.isNotEmpty) {
        port = int.tryParse(raw) ?? -1;
        if (port < 1 || port > 65535) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('smc_manual_port_out_of_range'.i18n)),
            );
          }
          return;
        }
      }
      final result =
          await ref.read(lanternServiceProvider).setPeerManualPort(port);
      result.fold(
        (err) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(err.localizedErrorMessage)),
            );
          }
        },
        (_) {
          lastSaved.value = port;
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(port == 0
                    ? 'smc_manual_port_cleared'.i18n
                    : 'smc_manual_port_saved'.i18n.fill([port])),
              ),
            );
          }
        },
      );
    } finally {
      saving.value = false;
    }
  }
}
