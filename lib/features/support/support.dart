import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/support/app_version.dart';

@RoutePage(name: 'Support')
class Support extends StatelessWidget {
  const Support({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: toBeginningOfSentenceCase('support'.i18n),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            Center(
              child: AppImage(
                path: AppImagePaths.supportIllustration,
                type: AssetType.svg,
                height: 180.h,
                width: 180.w,
              ),
            ),
            SizedBox(height: 16),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  AppTile(
                    icon: Icons.error_outline,
                    label: 'Report an Issue',
                    onPressed: () => appRouter.push(ReportIssue()),
                  ),
                  DividerSpace(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                  AppTile(
                    icon: Icons.code_outlined,
                    label: 'Diagnostic Logs',
                    onPressed: () => appRouter.push(Logs()),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  AppTile.link(
                    icon: Icons.forum_outlined,
                    label: 'Lantern User Forum',
                    url: AppUrls.support,
                  ),
                  DividerSpace(padding: EdgeInsets.symmetric(horizontal: 16)),
                  AppTile.link(
                    icon: Icons.info_outlined,
                    label: 'Frequently Asked Questions',
                    url: AppUrls.faq,
                  ),
                  DividerSpace(padding: EdgeInsets.symmetric(horizontal: 16)),
                  AppTile.link(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacy Policy',
                    url: AppUrls.privacyPolicy,
                  ),
                  DividerSpace(padding: EdgeInsets.symmetric(horizontal: 16)),
                  AppTile.link(
                    icon: Icons.description_outlined,
                    label: 'Terms of Service',
                    url: AppUrls.termsOfService,
                  ),
                ],
              ),
            ),
            // Spacer(),
            SizedBox(height: 16),
            AppVersion(version: '8.1.4 (20250213.213443)'),
            SizedBox(height: size24),
          ],
        ),
      ),
    );
  }
}
