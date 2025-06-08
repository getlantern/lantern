import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/private_server/provider_carousel.dart';
import 'package:lantern/features/support/app_version.dart';

@RoutePage(name: 'PrivateServerSetup')
class PrivateServerSetup extends StatelessWidget {
  const PrivateServerSetup({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'server_setup'.i18n,
      padded: true,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            Center(
              child: AppImage(
                path: AppImagePaths.serverRack,
                type: AssetType.svg,
                height: 180.h,
                width: 180.w,
              ),
            ),
            SizedBox(height: 16),
            ProviderCarousel(
              cards: [
                _buildProviderCard(
                  context,
                  title: 'server_setup_do'.i18n,
                  price: 'server_setup_do_price'.i18n.fill(['\$8']),
                  onContinue: () {},
                  icon: AppImagePaths.digitalOceanIcon,
                ),
                _buildProviderCard(
                  context,
                  title: 'server_setup_aws'.i18n,
                  price: 'server_setup_aws_price'.i18n.fill(['\$9']),
                  onContinue: () {},
                  icon: AppImagePaths.digitalOceanIcon,
                ),
              ],
            ),
            const SizedBox(height: 24),
            ContinueButton(label: 'continue_with_do'.i18n, onPressed: () {}),
            const SizedBox(height: 16),
            OutlineButton(label: 'server_setup_manual'.i18n, onPressed: () {}),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderCard(
    BuildContext context, {
    required String title,
    required String price,
    required VoidCallback onContinue,
    required String icon,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppColors.gray2,
        ),
      ),
      elevation: 4,
      shadowColor: AppColors.shadowColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppTile(
              icon: icon,
              label: title,
              tileTextStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.black1,
              ),
            ),
            Divider(color: AppColors.gray2),
            CheckmarkTile(
              text: 'handle_configuration'.i18n,
            ),
            CheckmarkTile(text: price),
            CheckmarkTile(text: 'seamless_integration'.i18n),
            CheckmarkTile(
              text: 'choose_location'.i18n,
              trailing:
                  AppIconButton(path: AppImagePaths.info, onPressed: () => {}),
            ),
            CheckmarkTile(
              text: 'one_month_included'.i18n.fill([1]),
            ),
          ],
        ),
      ),
    );
  }
}

class CheckmarkTile extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const CheckmarkTile({
    super.key,
    required this.text,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return AppTile(
      icon: AppImagePaths.checkmark,
      label: text,
      trailing: trailing,
    );
  }
}

class ContinueButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const ContinueButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: AppColors.blue10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.gray1,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class OutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const OutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        side: BorderSide(
          color: AppColors.gray5,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: AppTestStyles.titleMedium.copyWith(
          color: AppColors.black1,
        ),
      ),
    );
  }
}
