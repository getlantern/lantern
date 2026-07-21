import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/extensions/user_data.dart';
import 'package:lantern/core/utils/pro_utils.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

@RoutePage(name: 'InviteFriends')
class InviteFriends extends HookConsumerWidget {
  const InviteFriends({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(homeProvider).value;
    final referralCode = user!.legacyUserData.referral.toUpperCase();
    final bonusMonths = user.legacyUserData.referralBonusMonths;
    final isCopied = useState(false);
    final textTheme = Theme.of(context).textTheme;

    return BaseScreen(
      title: 'invite_friends'.i18n,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'invite_friends_description'.i18n,
              style: textTheme.bodyMedium!.copyWith(
                color: context.textSecondary,
              ),
            ),
          ),
          SizedBox(height: defaultSize),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              '${'your_referral_code'.i18n}:',
              style: textTheme.labelLarge!.copyWith(
                color: context.textSecondary,
              ),
            ),
          ),
          SizedBox(height: 4.0),
          Card(
            child: Column(
              children: [
                AppTile(
                  icon: AppImagePaths.star,
                  trailing: AnimatedCrossFade(
                    duration: Duration(milliseconds: 400),
                    firstCurve: Curves.bounceOut,
                    crossFadeState: isCopied.value
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: AppImage(path: AppImagePaths.copy),
                    secondChild: Icon(
                      Icons.check_circle,
                      color: context.statusSuccessBg,
                    ),
                  ),
                  label: referralCode,
                  tileTextStyle: AppTextStyles.bodyMediumBold.copyWith(
                    color: context.textPrimary,
                  ),
                  onPressed: () => _onCopyTap(isCopied, referralCode),
                ),
                if (bonusMonths > 0) ...[
                  DividerSpace(),
                  AppTile(
                    icon: Icon(
                      Icons.emoji_events_outlined,
                      color: context.textPromoIcon,
                    ),
                    label: bonusMonths == 1
                        ? 'month_earned'.i18n.fill([bonusMonths])
                        : 'months_earned'.i18n.fill([bonusMonths]),
                    trailing: AppTextButton(
                      label: 'view_account'.i18n,
                      underLine: false,
                      padding: EdgeInsets.zero,
                      onPressed: () => _onViewAccount(context, ref),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Spacer(),
          PrimaryButton(
            label: 'share_referral_code'.i18n,
            icon: AppImagePaths.share,
            isTaller: true,
            onPressed: () => _onShareTap(referralCode),
          ),
          SizedBox(height: defaultSize),
          SecondaryButton(
            label: 'show_download_links'.i18n,
            icon: AppImagePaths.qrCodeScanner,
            useThemeColor: true,
            onPressed: () => _showDownloadLinksSheet(context, referralCode),
          ),
          SizedBox(height: defaultSize),
        ],
      ),
    );
  }

  Future<void> _onCopyTap(
    ValueNotifier<bool> isCopied,
    String referralCode,
  ) async {
    copyToClipboard(referralCode);
    isCopied.value = true;
    await Future.delayed(Duration(seconds: 1));
    isCopied.value = false;
  }

  void _onShareTap(String referralCode) {
    Share.share('share_message_referral_code'.i18n.fill([referralCode]));
  }

  Future<void> _onViewAccount(BuildContext context, WidgetRef ref) async {
    final user = ref.read(homeProvider).value;
    final userLoggedIn = ref.read(appSettingProvider).userLoggedIn;
    await openAccountOrProAccountSetup(
      context: context,
      user: user,
      userLoggedIn: userLoggedIn,
    );
  }

  void _showDownloadLinksSheet(BuildContext context, String referralCode) {
    showAppBottomSheet(
      context: context,
      title: 'get_lantern'.i18n,
      scrollControlDisabledMaxHeightRatio: .6,
      builder: (context, scrollController) {
        return _GetLanternSheet(
          referralCode: referralCode,
          scrollController: scrollController,
        );
      },
    );
  }
}

enum _DownloadPlatform {
  android('Android'),
  windows('Windows'),
  macos('macOS');

  const _DownloadPlatform(this.label);

  final String label;

  String get url {
    switch (this) {
      case _DownloadPlatform.android:
        return AppUrls.directDownloadAndroid;
      case _DownloadPlatform.windows:
        return AppUrls.directDownloadWindows;
      case _DownloadPlatform.macos:
        return AppUrls.directDownloadMac;
    }
  }
}

class _GetLanternSheet extends HookWidget {
  const _GetLanternSheet({
    required this.referralCode,
    required this.scrollController,
  });

  final String referralCode;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final selectedPlatform = useState(_DownloadPlatform.android);
    final isCopied = useState(false);
    final textTheme = Theme.of(context).textTheme;
    final downloadUrl = selectedPlatform.value.url;

    return ListView(
      shrinkWrap: true,
      controller: scrollController,
      padding: EdgeInsets.symmetric(horizontal: 16.0),
      children: <Widget>[
        SizedBox(height: 10),
        Row(
          children: _DownloadPlatform.values
              .map(
                (platform) => Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: _platformTab(
                    context,
                    platform,
                    platform == selectedPlatform.value,
                    () => selectedPlatform.value = platform,
                  ),
                ),
              )
              .toList(),
        ),
        SizedBox(height: 10),
        DividerSpace(),
        SizedBox(height: 10),
        Text(
          'send_friend_download_link'.i18n,
          style: textTheme.bodyMedium!.copyWith(color: context.textSecondary),
        ),
        SizedBox(height: 8.0),
        _downloadLinkBox(context, isCopied, downloadUrl),
        if (selectedPlatform.value == _DownloadPlatform.android) ...[
          SizedBox(height: size24),
          Center(
            child: QrImageView(
              data: downloadUrl,
              version: QrVersions.auto,
              size: 150.0,
              backgroundColor: Colors.white,
            ),
          ),
          SizedBox(height: 8.0),
          Center(
            child: Text(
              'scan_to_install'.i18n,
              style: textTheme.labelMedium!.copyWith(
                color: context.textSecondary,
              ),
            ),
          ),
        ],
        SizedBox(height: size24),
        _reminderCallout(context),
        SizedBox(height: defaultSize),
      ],
    );
  }

  Widget _platformTab(
    BuildContext context,
    _DownloadPlatform platform,
    bool selected,
    VoidCallback onTap,
  ) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(24.0),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: selected ? context.bgHover : Colors.transparent,
          borderRadius: BorderRadius.circular(24.0),
        ),
        child: Text(
          platform.label,
          style: textTheme.labelLarge!.copyWith(
            color: selected ? context.textPrimary : context.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _downloadLinkBox(
    BuildContext context,
    ValueNotifier<bool> isCopied,
    String downloadUrl,
  ) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(8.0),
      onTap: () => _onCopyTap(isCopied, downloadUrl),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: context.bgCallout,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                downloadUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium!.copyWith(
                  color: context.textPrimary,
                ),
              ),
            ),
            SizedBox(width: 8.0),
            AnimatedCrossFade(
              duration: Duration(milliseconds: 400),
              firstCurve: Curves.bounceOut,
              crossFadeState: isCopied.value
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: AppImage(path: AppImagePaths.copy),
              secondChild: Icon(
                Icons.check_circle,
                color: context.statusSuccessBg,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reminderCallout(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final template = 'remind_use_code'.i18n;
    final parts = template.split('%s');
    return Container(
      padding: EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: context.bgHover,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        children: [
          AppImage(path: AppImagePaths.star),
          SizedBox(width: 12.0),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: textTheme.bodyMedium!.copyWith(
                  color: context.textPrimary,
                ),
                children: [
                  TextSpan(text: parts.first),
                  TextSpan(
                    text: referralCode,
                    style: AppTextStyles.bodyMediumBold.copyWith(
                      color: context.textPrimary,
                    ),
                  ),
                  if (parts.length > 1) TextSpan(text: parts[1]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onCopyTap(
    ValueNotifier<bool> isCopied,
    String downloadUrl,
  ) async {
    copyToClipboard(downloadUrl);
    isCopied.value = true;
    await Future.delayed(Duration(seconds: 1));
    isCopied.value = false;
  }
}
