import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';
import 'package:share_plus/share_plus.dart';

@RoutePage(name: 'InviteFriends')
class InviteFriends extends HookConsumerWidget {
  const InviteFriends({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(homeNotifierProvider).value;
    final referralCode = user!.legacyUserData.referral.toUpperCase();
    return BaseScreen(title: 'invite_friends'.i18n, body: _buildBody(referralCode));
  }

  Widget _buildBody(String referralCode) {
    final isCopied = useState(false);
    final textTheme = Theme.of(useContext()).textTheme;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(child: AppImage(path: AppImagePaths.startIllustration)),
          SizedBox(height: defaultSize),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'your_referral_code'.i18n,
              style: textTheme.labelLarge!.copyWith(
                color: AppColors.gray8,
              ),
            ),
          ),
          SizedBox(height: 4.0),
          Card(
            child: AppTile(
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
                  color: AppColors.green7,
                ),
              ),
              label: referralCode,
              onPressed: () => _onCopyTap(isCopied, referralCode),
            ),
          ),
          SizedBox(height: defaultSize),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'invite_friends_message'.i18n,
              style: textTheme.bodyMedium!.copyWith(
                color: AppColors.gray8,
              ),
            ),
          ),
          SizedBox(height: 48.0.h),
          PrimaryButton(
            label: 'share_referral_code'.i18n,
            icon: AppImagePaths.share,
            onPressed: () => _onShareTap('BSDKALE'),
          ),
        ],
      ),
    );
  }

  Future<void> _onCopyTap(
      ValueNotifier<bool> isCopied, String referralCode) async {
    copyToClipboard(referralCode);
    isCopied.value = true;
    await Future.delayed(Duration(seconds: 1));
    isCopied.value = false;
  }

  void _onShareTap(String referralCode) {
    Share.share('share_message_referral_code'.i18n.fill([referralCode]));
  }
}
