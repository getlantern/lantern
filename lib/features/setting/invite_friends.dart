import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/base_screen.dart';

@RoutePage(name: 'InviteFriends')
class InviteFriends extends StatefulWidget {
  const InviteFriends({super.key});

  @override
  State<InviteFriends> createState() => _InviteFriendsState();
}

class _InviteFriendsState extends State<InviteFriends> {
  @override
  Widget build(BuildContext context) {
    return BaseScreen(title: 'invite_friends'.i18n, body: _buildBody());
  }

  Widget _buildBody() {
    final textTheme = Theme.of(context).textTheme;
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
              trailing: AppImage(path: AppImagePaths.copy),
              label: 'BSDKALE',
              onPressed: () {},
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
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
