import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Manual port forward, for routers without UPnP. Takes effect the next time
/// sharing is turned on.
class _AdvancedCard extends StatelessWidget {
  const _AdvancedCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Theme(
        // The card border already outlines the section.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: defaultSize),
          childrenPadding: const EdgeInsets.fromLTRB(
            defaultSize,
            0,
            defaultSize,
            defaultSize,
          ),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: Text(
            'smc_advanced'.i18n,
            style: textTheme.bodyLarge?.copyWith(color: context.textPrimary),
          ),
          subtitle: Text(
            'smc_advanced_subtitle'.i18n,
            style: textTheme.labelMedium?.copyWith(color: context.textTertiary),
          ),
          iconColor: context.textPrimary,
          collapsedIconColor: context.textPrimary,
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
    final ready = loaded.value && !saving.value;

    // One-shot load; the guard keeps a late result from writing to disposed
    // controllers.
    useEffect(() {
      var disposed = false;
      Future.microtask(() async {
        final result = await ref
            .read(lanternServiceProvider)
            .getPeerManualPort();
        if (disposed) return;
        // A failed read leaves the controls disabled: saving the empty field
        // would clear a port the user may have configured.
        result.fold((_) => null, (port) {
          if (port > 0) controller.text = port.toString();
          lastSaved.value = port;
          loaded.value = true;
        });
      });
      return () => disposed = true;
    }, const []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'smc_manual_port'.i18n,
          style: textTheme.titleMedium?.copyWith(color: context.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          'smc_manual_port_description'.i18n,
          style: textTheme.bodySmall?.copyWith(color: context.textSecondary),
        ),
        const SizedBox(height: defaultSize),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: AppTextField(
                label: 'smc_manual_port_label'.i18n,
                hintText: 'smc_manual_port_hint'.i18n,
                controller: controller,
                prefixIcon: Icons.settings_ethernet,
                enable: ready,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 5,
                autovalidateMode: AutovalidateMode.disabled,
                onSubmitted: (_) =>
                    _save(ref, context, controller, saving, lastSaved),
              ),
            ),
            const SizedBox(width: 12),
            PrimaryButton(
              label: 'smc_manual_port_save'.i18n,
              expanded: false,
              enabled: ready,
              onPressed: () =>
                  _save(ref, context, controller, saving, lastSaved),
            ),
          ],
        ),
        if (lastSaved.value != null && lastSaved.value! > 0) ...[
          const SizedBox(height: 8),
          Text(
            'smc_manual_port_currently_set'.i18n.fill([lastSaved.value!]),
            style: textTheme.bodySmall?.copyWith(color: context.textTertiary),
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
      final result = await ref
          .read(lanternServiceProvider)
          .setPeerManualPort(port);
      result.fold(
        (err) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(err.localizedErrorMessage)));
          }
        },
        (_) {
          lastSaved.value = port;
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  port == 0
                      ? 'smc_manual_port_cleared'.i18n
                      : 'smc_manual_port_saved'.i18n.fill([port]),
                ),
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
