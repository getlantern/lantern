import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/info_row.dart';

@RoutePage(name: 'PrivateServerAddBilling')
class PrivateServerAddBilling extends StatelessWidget {
  const PrivateServerAddBilling({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return BaseScreen(
      title: 'add_billing_details'.i18n,
      body: Column(
        children: <Widget>[
          InfoRow(text: 'do_billing_details_message'.i18n),
          SizedBox(height: defaultSize),
          AppCard(
            padding: EdgeInsets.all(defaultSize),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SizedBox(height: defaultSize),
                Center(
                  child: AppImage(
                    path: AppImagePaths.creditCard,
                    color: AppColors.gray9,
                    height: 30,
                  ),
                ),

                SizedBox(height: defaultSize),
                Center(
                  child: Text(
                    'how_to_add_billing_details'.i18n,
                    style: textTheme.titleMedium,
                  ),
                ),
                SizedBox(height: defaultSize),
                RichText(
                  textAlign: TextAlign.left,
                  text: TextSpan(
                    style:
                        textTheme.bodyMedium!.copyWith(color: AppColors.gray8),
                    text: '${'1'.i18n}. ',
                    children: [
                      TextSpan(text: '${'tap'.i18n} '),
                      TextSpan(
                          text: '${'open_system_settings'.i18n} ',
                          style: AppTextStyles.bodyMediumBold!.copyWith(
                            color: AppColors.gray8,
                          )),
                      TextSpan(text: 'below_to_go_to_do'.i18n),
                    ],
                  ),
                ),
                SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    style:
                        textTheme.bodyMedium!.copyWith(color: AppColors.gray8),
                    text: '${'2'.i18n}. ',
                    children: [
                      TextSpan(text: '${'add_payment_method'.i18n} '),
                    ],
                  ),
                ),
                SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    style:
                        textTheme.bodyMedium!.copyWith(color: AppColors.gray8),
                    text: '${'3'.i18n}. ',
                    children: [
                      TextSpan(text: '${'return_to_lantern'.i18n} '),
                    ],
                  ),
                ),
                SizedBox(height: 8),
              ],
            ),
          ),
          Spacer(),
          PrimaryButton(
            isTaller: true,
            icon: AppImagePaths.outsideBrowser,
            iconColor: AppColors.white,
            label: 'open_system_settings'.i18n,
            onPressed: () {},
          ),
          SizedBox(height: defaultSize),
          SecondaryButton(
            isTaller: true,
            label: 'continue'.i18n,
            onPressed: () {},
          )
        ],
      ),
    );
  }
}
