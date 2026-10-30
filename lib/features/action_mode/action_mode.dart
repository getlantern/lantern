import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/share_state.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/action_mode/action_mode_widgets.dart';
import 'package:lantern/features/action_mode/advanced_stats_sheet.dart';
import 'package:lantern/features/action_mode/peer_status_pill.dart';
import 'package:lantern/features/action_mode/provider/share_notifier.dart';
import 'package:lantern/features/action_mode/provider/action_mode_tab_visible_notifier.dart';
import 'package:lantern/features/action_mode/action_mode_globe.dart';
import 'package:lantern/features/action_mode/action_mode_welcome_dialog.dart';
import 'package:lantern/features/helpers/helping_section.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';

/// Unbounded tab body, hosted by the Home tab shell.
class ActionModeTab extends HookConsumerWidget {
  const ActionModeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(shareProvider);
    final visible = ref.watch(actionModeTabVisibleProvider);
    final helperInvites = ref.watch(helperInvitesAvailableProvider);
    final helping = ref.watch(
      helpersProvider.select((s) => s.view.helping.isNotEmpty),
    );
    // A volunteer waiting on a claim gets back to its code from here.
    final waiting = ref.watch(
      helpersProvider.select(
        (s) => s.view
            .waitingClaims(DateTime.now().millisecondsSinceEpoch ~/ 1000)
            .isNotEmpty,
      ),
    );

    useEffect(() {
      // refreshIfUsed, never refresh: showing the tab must not touch the
      // keystore of someone who has not used helper invites.
      if (visible && AppBuildInfo.enableHelperInvites) {
        final helpers = ref.read(helpersProvider.notifier);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(helpers.refreshIfUsed());
        });
      }
      return null;
    }, [visible]);

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

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(defaultSize),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: math.max(180, constraints.maxHeight - 264),
                      ),
                      child: const Stack(
                        alignment: Alignment.bottomCenter,
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(child: ActionModeGlobe()),
                          Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Center(child: PeerStatusPill()),
                          ),
                        ],
                      ),
                    ),
                    _StatusCard(
                      state: state,
                      onToggle: () =>
                          ref.read(shareProvider.notifier).toggle(context, ref),
                      onInfo: () => showActionModeWelcomeDialog(context, ref),
                    ),
                    // Needs no flag: a volunteer abroad is never flagged, so
                    // that nobody in their country sees the inviter UI.
                    if (AppBuildInfo.enableHelperInvites)
                      const HelpingSection(),
                    if (AppBuildInfo.enableHelperInvites &&
                        (helperInvites || helping || waiting)) ...[
                      const SizedBox(height: defaultSize),
                      AppTextButton(
                        label: 'help_friend_entry'.i18n,
                        onPressed: () => appRouter.push(HelpFriend()),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final ShareState state;
  final VoidCallback onToggle;
  final VoidCallback onInfo;

  const _StatusCard({
    required this.state,
    required this.onToggle,
    required this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    final hasError =
        state.phase == SharePhase.error ||
        (state.errorMessage?.isNotEmpty ?? false);
    final error = state.errorMessage != null
        ? 'smc_status_error_with_message'.i18n.fill([state.errorMessage!])
        : 'smc_status_error_generic'.i18n;

    // Show Off when disabled, Enabled when ready, and Configuring during startup.
    // Unbounded shows a waiting status until ready. Errors take precedence,
    // including failed stops while sharing is still active.
    final status = hasError
        ? error
        : switch (state.mode) {
            ShareMode.off =>
              state.probing
                  ? 'smc_status_configuring'.i18n
                  : 'smc_status_off'.i18n,
            ShareMode.unbounded =>
              state.unboundedRunning
                  ? 'enabled'.i18n
                  : 'unbounded_status_waiting'.i18n,
            ShareMode.smc => switch (state.phase) {
              SharePhase.serving => 'enabled'.i18n,
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
      hasError: hasError,
      activeCount: state.activeCount,
      totalCount: state.totalCount,
      onToggle: onToggle,
      onInfo: onInfo,
      onTotalTap: () => showAdvancedStatsSheet(context),
    );
  }
}
