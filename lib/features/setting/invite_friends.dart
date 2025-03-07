import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lantern/core/common/common.dart';
import 'package:share_plus/share_plus.dart';

@RoutePage(name: 'InviteFriends')
class InviteFriends extends HookWidget {
  const InviteFriends({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScreen(title: 'invite_friends'.i18n, body: _buildBody());
  }

  Widget _buildBody() {
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
              label: 'BSDKALE',
              onPressed: () => _onCopyTap(isCopied, 'BSDKALE'),
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
    isCopied.value = true;
    await Future.delayed(Duration(seconds: 1));
    isCopied.value = false;
  }

  void _onShareTap(String referralCode) {
    Share.share('share_message_referral_code'.i18n.fill([referralCode]));
  }
}
