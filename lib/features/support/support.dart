import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/utils/route_utils.dart';
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
            gap16,
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  AppTile(
                    icon: Icons.error_outline,
                    label: 'report_an_issue'.i18n,
                    onPressed: () => safePush(context, ReportIssue()),
                  ),
                  if (!PlatformUtils.isIOS) ...{
                    const DividerSpace(
                        padding: EdgeInsets.symmetric(horizontal: 16)),
                    AppTile(
                      icon: Icons.code_outlined,
                      label: 'diagnostic_logs'.i18n,
                      onPressed: () => safePush(context, Logs()),
                    ),
                  }
                ],
              ),
            ),
            gap16,
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  AppTile.link(
                    icon: Icons.forum_outlined,
                    label: 'lantern_user_forum'.i18n,
                    url: AppUrls.lanternForums,
                    open: (u) =>
                        UrlUtils.tryLaunchExternalUrl(context, Uri.parse(u)),
                  ),
                  const DividerSpace(
                      padding: EdgeInsets.symmetric(horizontal: 16)),
                  AppTile.link(
                    icon: Icons.info_outlined,
                    label: 'frequently_asked_questions'.i18n,
                    url: AppUrls.faq,
                    open: (u) =>
                        UrlUtils.tryLaunchExternalUrl(context, Uri.parse(u)),
                  ),
                  const DividerSpace(
                      padding: EdgeInsets.symmetric(horizontal: 16)),
                  AppTile.link(
                    icon: Icons.privacy_tip_outlined,
                    label: 'privacy_policy'.i18n,
                    url: AppUrls.privacyPolicy,
                    open: (u) =>
                        UrlUtils.tryLaunchExternalUrl(context, Uri.parse(u)),
                  ),
                  const DividerSpace(
                      padding: EdgeInsets.symmetric(horizontal: 16)),
                  AppTile.link(
                    icon: Icons.description_outlined,
                    label: 'terms_of_service'.i18n,
                    url: AppUrls.termsOfService,
                    open: (u) =>
                        UrlUtils.tryLaunchExternalUrl(context, Uri.parse(u)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: defaultSize),
            const AppVersion(),
            const SizedBox(height: size24),
          ],
        ),
      ),
    );
  }
}
