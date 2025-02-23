import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lantern/core/common/app_urls.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/base_screen.dart';
import 'package:lantern/features/support/app_version.dart';

@RoutePage(name: 'Support')
class Support extends HookConsumerWidget {
  const Support({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<AppTile> tiles = [
      AppTile(
        icon: Icons.error_outline,
        label: 'Report an Issue',
      ),
      AppTile(
        icon: Icons.code_outlined,
        label: 'Diagnostic Logs',
        dividerPadding: EdgeInsets.symmetric(vertical: 4),
      ),
      AppTile.link(
        icon: Icons.forum_outlined,
        label: 'Lantern User Forum',
        url: AppUrls.support,
      ),
      AppTile.link(
        icon: Icons.info_outlined,
        label: 'Frequently Asked Questions',
        url: AppUrls.faq,
      ),
      AppTile.link(
        icon: Icons.privacy_tip_outlined,
        label: 'Privacy Policy',
        url: AppUrls.privacyPolicy,
      ),
      AppTile.link(
        icon: Icons.description_outlined,
        label: 'Terms of Service',
        url: AppUrls.termsOfService,
        dividerPadding: EdgeInsets.symmetric(vertical: 8),
      ),
    ];

    return BaseScreen(
      title: toBeginningOfSentenceCase('support'.i18n),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: AppAsset(
              path: AppImagePaths.supportIllustration,
              type: AssetType.svg,
              height: 180.h,
              width: 180.w,
            ),
          ),
          SizedBox(height: defaultSize),
          ...tiles,
        ],
      ),
      // TODO: update to use dynamic version
      bottomNavigationBar: AppVersion(version: '8.1.4 (20250213.213443)'),
    );
  }
}
