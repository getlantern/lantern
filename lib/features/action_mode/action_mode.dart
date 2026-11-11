import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/share_state.dart';
import 'package:lantern/core/utils/country_code.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/home/provider/country_code_notifier.dart';
import 'package:lantern/features/action_mode/action_mode_widgets.dart';
import 'package:lantern/features/action_mode/advanced_stats_sheet.dart';
import 'package:lantern/features/action_mode/peer_status_pill.dart';
import 'package:lantern/features/action_mode/provider/share_notifier.dart';
import 'package:lantern/features/action_mode/provider/action_mode_tab_visible_notifier.dart';
import 'package:lantern/features/action_mode/action_mode_globe.dart';
import 'package:lantern/features/action_mode/action_mode_welcome_dialog.dart';
import 'package:lantern/features/helpers/helping_friends.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';

/// The globe's least height before the content below it scrolls.
const _minGlobeHeight = 140.0;

/// Unbounded tab body, hosted by the Home tab shell.
class ActionModeTab extends HookConsumerWidget {
  const ActionModeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(shareProvider);
    final visible = ref.watch(actionModeTabVisibleProvider);
    // A volunteer is someone abroad: the row stays hidden where sharing may
    // not start on its own (unknown or censored country), and in stealth. A
    // volunteer waiting on a claim gets back to its code from here wherever
    // it is, even before the country is known.
    final waiting = ref.watch(
      helpersProvider.select(
        (s) => s.view
            .waitingClaims(DateTime.now().millisecondsSinceEpoch ~/ 1000)
            .isNotEmpty,
      ),
    );
    final helpsSomeone = ref.watch(
      helpersProvider.select((s) => s.view.helping.isNotEmpty),
    );
    final keystoreReset = ref.watch(
      helpersProvider.select((s) => s.keystoreReset),
    );
    // Exactly one of the two: "Become a Personal Proxy" before the first
    // pairing, then "Your Personal Proxy connections". A volunteer is never
    // flagged, so that nobody in their country sees the inviter UI.
    final connectionsCard = AppBuildInfo.enableHelperInvites && helpsSomeone;
    final becomeRow =
        AppBuildInfo.enableHelperInvites &&
        !helpsSomeone &&
        (waiting || helperAutoStartAllowed(ref.watch(countryCodeProvider)));
    // "Helping right now" opens Who you're helping, and says whom.
    final scopeShown = HelpersNotifier.buildEnabled;
    final helpOthers = ref.watch(
      helpersProvider.select((s) => s.chosenHelpOthers),
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
      // A settings read, not the keystore.
      if (visible && scopeShown) {
        final helpers = ref.read(helpersProvider.notifier);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(helpers.loadHelpOthers());
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
                child: _GlobeColumn(
                  // The window's height less the tab's padding: what the
                  // content fills, with the padding under the last card,
                  // when it fits.
                  viewportHeight: constraints.maxHeight - 2 * defaultSize,
                  minGlobeHeight: _minGlobeHeight,
                  children: [
                    // Status, both counts and the Personal Proxy card stay above
                    // the fold: the globe gives up the room first.
                    const Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(child: ActionModeGlobe()),
                        // Align, not Center: Center fills the slot and puts
                        // the pill over the sphere's middle. The globe keeps
                        // the slot's bottom clear for it.
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: PeerStatusPill(),
                          ),
                        ),
                      ],
                    ),
                    _StatusCard(
                      state: state,
                      onToggle: () =>
                          ref.read(shareProvider.notifier).toggle(context, ref),
                      onInfo: () => showActionModeWelcomeDialog(context, ref),
                      helpingScope: scopeShown
                          ? helpingScopeLabel(helpOthers)
                          : null,
                      onHelpingTap: scopeShown
                          ? () => showWhoYoureHelpingSheet(context)
                          : null,
                    ),
                    // A volunteer who never opens the friends sheet must still
                    // learn that the keystore lost the old names.
                    if (AppBuildInfo.enableHelperInvites && keystoreReset) ...[
                      const SizedBox(height: _cardGap),
                      HelperKeystoreResetNotice(
                        notifier: ref.read(helpersProvider.notifier),
                      ),
                    ],
                    if (connectionsCard) ...[
                      const SizedBox(height: _cardGap),
                      const PersonalProxyConnectionsCard(),
                    ] else if (becomeRow) ...[
                      const SizedBox(height: _cardGap),
                      AppCard(
                        padding: EdgeInsets.zero,
                        shadow: true,
                        child: AppTile(
                          tileKey: const Key(
                            'action_mode.become_personal_proxy',
                          ),
                          icon: AppImagePaths.key,
                          label: 'become_personal_proxy'.i18n,
                          // The same line as "View advanced stats" above it.
                          subtitle: Text(
                            'become_personal_proxy_body'.i18n,
                            style: Theme.of(context).textTheme.labelLarge!
                                .copyWith(color: context.textTertiary),
                          ),
                          trailing: const AppImage(
                            path: AppImagePaths.arrowForward,
                          ),
                          onPressed: () => appRouter.push(HelpFriend()),
                        ),
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

/// The gap between the tab's cards, as between the VPN tab's.
const _cardGap = 8.0;

/// A column whose first child, the globe, gets the height [viewportHeight]
/// leaves after the others, and never less than [minGlobeHeight]: the
/// content fills the window when it fits, and scrolls when it does not. A
/// plain Column cannot do this in a scroll view, and measuring the cards
/// first is not possible either, as the globe sizes itself from its
/// constraints alone.
class _GlobeColumn extends MultiChildRenderObjectWidget {
  const _GlobeColumn({
    required this.viewportHeight,
    required this.minGlobeHeight,
    required super.children,
  });

  final double viewportHeight;
  final double minGlobeHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderGlobeColumn(viewportHeight, minGlobeHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderGlobeColumn renderObject,
  ) {
    renderObject
      ..viewportHeight = viewportHeight
      ..minGlobeHeight = minGlobeHeight;
  }
}

class _GlobeColumnParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderGlobeColumn extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _GlobeColumnParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _GlobeColumnParentData> {
  _RenderGlobeColumn(this._viewportHeight, this._minGlobeHeight);

  double _viewportHeight;
  set viewportHeight(double value) {
    if (value == _viewportHeight) return;
    _viewportHeight = value;
    markNeedsLayout();
  }

  double _minGlobeHeight;
  set minGlobeHeight(double value) {
    if (value == _minGlobeHeight) return;
    _minGlobeHeight = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _GlobeColumnParentData) {
      child.parentData = _GlobeColumnParentData();
    }
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final globe = firstChild;
    if (globe == null) {
      size = constraints.smallest;
      return;
    }
    // The cards size themselves, as wide as the column.
    final column = BoxConstraints(minWidth: width, maxWidth: width);
    var rest = 0.0;
    for (
      var child = childAfter(globe);
      child != null;
      child = childAfter(child)
    ) {
      child.layout(column, parentUsesSize: true);
      rest += child.size.height;
    }
    final globeHeight = math.max(_minGlobeHeight, _viewportHeight - rest);
    globe.layout(
      BoxConstraints.tightFor(width: width, height: globeHeight),
      parentUsesSize: true,
    );
    var top = 0.0;
    for (RenderBox? child = globe; child != null; child = childAfter(child)) {
      (child.parentData! as _GlobeColumnParentData).offset = Offset(0, top);
      top += child.size.height;
    }
    size = constraints.constrain(Size(width, top));
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

class _StatusCard extends StatelessWidget {
  final ShareState state;
  final VoidCallback onToggle;
  final VoidCallback onInfo;
  final String? helpingScope;
  final VoidCallback? onHelpingTap;

  const _StatusCard({
    required this.state,
    required this.onToggle,
    required this.onInfo,
    this.helpingScope,
    this.onHelpingTap,
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
      helpingScope: helpingScope,
      onHelpingTap: onHelpingTap,
    );
  }
}
