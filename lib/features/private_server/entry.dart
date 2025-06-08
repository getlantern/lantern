import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/private_server/provider_card.dart';
import 'package:lantern/features/private_server/provider_carousel.dart';

@RoutePage(name: 'PrivateServerSetup')
class PrivateServerSetup extends StatelessWidget {
  const PrivateServerSetup({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'setup_private_server'.i18n,
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
                ProviderCard(
                  title: 'server_setup_do'.i18n,
                  price: 'server_setup_do_price'.i18n.fill(['\$8']),
                  onContinue: () {},
                  icon: AppImagePaths.digitalOceanIcon,
                ),
                ProviderCard(
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
            OutlineButton(
              label: 'server_setup_manual'.i18n,
              onPressed: () {},
            ),
          ],
        ),
      ),
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
        style: AppTestStyles.primaryButtonTextStyle.copyWith(
          color: AppColors.gray1,
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
