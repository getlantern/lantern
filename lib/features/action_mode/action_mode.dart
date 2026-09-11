import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/share_state.dart';
import 'package:lantern/core/widgets/info_row.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/action_mode/action_mode_widgets.dart';
import 'package:lantern/features/action_mode/peer_status_pill.dart';
import 'package:lantern/features/action_mode/auto_enable_mode.dart';
import 'package:lantern/features/action_mode/provider/share_notifier.dart';
import 'package:lantern/features/action_mode/provider/action_mode_tab_visible_notifier.dart';
import 'package:lantern/features/action_mode/action_mode_globe.dart';
import 'package:lantern/features/action_mode/action_mode_welcome_dialog.dart';

/// Unbounded tab body, hosted by the Home tab shell.
class ActionModeTab extends HookConsumerWidget {
  const ActionModeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(shareProvider);
    final visible = ref.watch(actionModeTabVisibleProvider);

    useEffect(() {
      if (visible && !ref.read(appSettingProvider).unboundedWelcomeSeen) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted && ref.read(actionModeTabVisibleProvider)) {
            showActionModeWelcomeDialog(context, ref);
          }
        });
      }
      return null;
    }, [visible]);

    // The globe fills whatever the cards leave over; the page only scrolls
    // when the cards alone are taller than the screen.
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(defaultSize),
              child: Column(
                children: [
                  InfoRow(
                    text: 'smc_intro'.i18n,
                    onPressed: () => showActionModeWelcomeDialog(context, ref),
                  ),
                  const Expanded(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(child: ActionModeGlobe()),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 8,
                          child: Center(child: PeerStatusPill()),
                        ),
                      ],
                    ),
                  ),
                  _StatusCard(
                    state: state,
                    onToggle: () =>
                        ref.read(shareProvider.notifier).toggle(context, ref),
                  ),
                  const SizedBox(height: 8),
                  const ActionModeAutoEnable(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final ShareState state;
  final VoidCallback onToggle;

  const _StatusCard({required this.state, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final error = state.errorMessage != null
        ? 'smc_status_error_with_message'.i18n.fill([state.errorMessage!])
        : 'smc_status_error_generic'.i18n;

    // Three states per spec: Off, Enabled, and Configuring while a start or
    // probe is in flight. An error while off is terminal and shown as-is.
    final status = switch (state.mode) {
      ShareMode.off => switch (state.phase) {
        SharePhase.error => error,
        _ =>
          state.probing ? 'smc_status_configuring'.i18n : 'smc_status_off'.i18n,
      },
      ShareMode.unbounded =>
        state.unboundedRunning
            ? 'enabled'.i18n
            : 'unbounded_status_waiting'.i18n,
      ShareMode.smc => switch (state.phase) {
        SharePhase.serving => 'enabled'.i18n,
        SharePhase.error => error,
        _ => 'smc_status_configuring'.i18n,
      },
    };

    return ActionModeStatusCard(
      status: status,
      enabled: state.active || state.probing,
      ready:
          (state.mode == ShareMode.unbounded && state.unboundedRunning) ||
          (state.mode == ShareMode.smc && state.phase == SharePhase.serving),
      busy: state.probing,
      hasError: state.phase == SharePhase.error,
      activeCount: state.activeCount,
      totalCount: state.totalCount,
      onToggle: onToggle,
    );
  }
}
