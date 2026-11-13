import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/globe_column.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';

import 'onboarding.dart';

/// Onboarding's Action Mode page, where Action Mode is offered. It only
/// explains: Action Mode starts from its tab, through the consent dialog.
/// The rows fit above the button without scrolling where they can: the
/// globe shrinks to make room, then goes. Only text too tall for the page
/// on its own, as with a short window and large system text, scrolls.
class OnboardingActionModePage extends StatelessWidget {
  const OnboardingActionModePage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = TextTheme.of(context);
    return LayoutBuilder(
      key: const Key('onboarding.action_mode'),
      builder: (context, constraints) => SingleChildScrollView(
        child: GlobeColumn(
          viewportHeight: constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : 0,
          minGlobeHeight: 0,
          // The globe's place in the children below.
          globeIndex: 4,
          children: <Widget>[
            const SizedBox(height: 24.0),
            Text(
              'unbounded'.i18n,
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall!.copyWith(
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              'onboarding_action_mode_subtitle'.i18n,
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge!.copyWith(
                color: context.textSecondary,
              ),
            ),
            const _Globe(),
            _row(
              icon: AppImagePaths.shareV2,
              title: 'onboarding_action_mode_share'.i18n,
              description: 'onboarding_action_mode_share_description'.i18n,
            ),
            // Being a Personal Proxy needs a build with helper invites.
            if (HelpersNotifier.buildEnabled) ...[
              const SizedBox(height: 16.0),
              _row(
                key: const Key('onboarding.action_mode.help_someone'),
                icon: AppImagePaths.personAdd,
                title: 'onboarding_action_mode_help_someone'.i18n,
                description:
                    'onboarding_action_mode_help_someone_description'.i18n,
                isNew: true,
              ),
            ],
            const SizedBox(height: 16.0),
            _row(
              icon: AppImagePaths.verifiedUser,
              title: 'onboarding_action_mode_privacy'.i18n,
              description: 'onboarding_action_mode_privacy_description'.i18n,
            ),
            const SizedBox(height: 16.0),
            _row(
              icon: AppImagePaths.toggleOn,
              title: 'onboarding_action_mode_control'.i18n,
              description: 'onboarding_action_mode_control_description'.i18n,
            ),
            const SizedBox(height: onboardingIndicatorSpace),
          ],
        ),
      ),
    );
  }

  // The design's rows: text a little wider than the page's other rows.
  Widget _row({
    Key? key,
    required String icon,
    required String title,
    required String description,
    bool isNew = false,
  }) => OnboardingFeatureRow(
    rowKey: key,
    contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
    icon: OnboardingIconTile(path: icon),
    title: title,
    description: description,
    isNew: isNew,
  );
}

/// The page's globe illustration, with its gaps above and below. Its glow
/// reaches past the box it takes in the layout, as in the design. It takes
/// the room left between the subtitle and the rows: at full size when there
/// is enough, smaller when there is less, and none when too little is left
/// to show it.
class _Globe extends StatelessWidget {
  const _Globe();

  static const _width = 192.0;
  static const _height = 165.5;
  static const _gap = 24.0;

  /// Smaller than this, the globe goes rather than shrinks further.
  static const _minHeight = 72.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final max = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : _height + 2 * _gap;
        final room = max - 2 * _gap;
        if (room < _minHeight) {
          return SizedBox(height: math.min(max, _gap));
        }
        final height = math.min(room, _height);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: _gap),
          child: SizedBox(
            width: _width * height / _height,
            height: height,
            child: const FittedBox(
              child: SizedBox(
                width: _width,
                height: _height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: -38.1,
                      top: -61.5,
                      width: 268.2,
                      height: 275.6,
                      child: AppImage(
                        path: AppImagePaths.onboardingActionModeGlobe,
                        type: AssetType.png,
                        fit: BoxFit.fill,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
