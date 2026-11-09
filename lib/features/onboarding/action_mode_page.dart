import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';

import 'onboarding.dart';

/// Onboarding's Action Mode page, where Action Mode is offered. It only
/// explains: Action Mode starts from its tab, through the consent dialog.
class OnboardingActionModePage extends StatelessWidget {
  const OnboardingActionModePage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = TextTheme.of(context);
    return SingleChildScrollView(
      key: const Key('onboarding.action_mode'),
      child: Column(
        children: <Widget>[
          const SizedBox(height: 24.0),
          Text(
            'unbounded'.i18n,
            textAlign: TextAlign.center,
            style: textTheme.headlineSmall!.copyWith(
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            'onboarding_action_mode_subtitle'.i18n,
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge!.copyWith(color: context.textSecondary),
          ),
          const SizedBox(height: 24.0),
          const _Globe(),
          const SizedBox(height: 24.0),
          _row(
            context,
            icon: AppImagePaths.shareV2,
            title: 'onboarding_action_mode_share'.i18n,
            description: 'onboarding_action_mode_share_description'.i18n,
          ),
          // Being a Personal Proxy needs a build with helper invites.
          if (HelpersNotifier.buildEnabled) ...[
            const SizedBox(height: 16.0),
            _row(
              context,
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
            context,
            icon: AppImagePaths.verifiedUser,
            title: 'onboarding_action_mode_privacy'.i18n,
            description: 'onboarding_action_mode_privacy_description'.i18n,
          ),
          const SizedBox(height: 16.0),
          _row(
            context,
            icon: AppImagePaths.toggleOn,
            title: 'onboarding_action_mode_control'.i18n,
            description: 'onboarding_action_mode_control_description'.i18n,
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    Key? key,
    required String icon,
    required String title,
    required String description,
    bool isNew = false,
  }) {
    final textTheme = TextTheme.of(context);
    final label = Text(
      title,
      style: textTheme.titleMedium!.copyWith(color: context.textPrimary),
    );
    // The design's rows: icon level with the title, text a little wider.
    return AppTile(
      tileKey: key,
      titleAlignment: ListTileTitleAlignment.top,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
      icon: OnboardingIconTile(path: icon),
      label: '',
      labelWidget: isNew
          ? Row(
              children: [
                Flexible(child: label),
                const SizedBox(width: 8.0),
                const NewBadge(),
              ],
            )
          : label,
      subtitle: Text(
        description,
        style: textTheme.bodyMedium!.copyWith(color: context.textSecondary),
      ),
    );
  }
}

/// The page's globe illustration. Its glow reaches past the box it takes in
/// the layout, as in the design.
class _Globe extends StatelessWidget {
  const _Globe();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 192.0,
      height: 165.5,
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
    );
  }
}
