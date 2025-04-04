import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/app_pin_field.dart';
import 'package:lantern/core/widgets/app_rich_text.dart';

@RoutePage(name: 'ConfirmEmail')
class ConfirmEmail extends StatelessWidget {
  final String email;

  const ConfirmEmail({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return BaseScreen(
      title: 'confirm_email'.i18n,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              'confirm_email_code'.i18n,
              style: textTheme.labelLarge?.copyWith(
                color: AppColors.gray8,
                fontSize: 14.sp,
              ),
            ),
          ),
          const SizedBox(height: 8),
          AppPinField(
            onCompleted: (String value) {
              // Handle the completed PIN code here
              appLogger.info('PIN code entered: $value');
            },
          ),
          SizedBox(height: defaultSize),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppRichText(
              texts: 'confirm_email_code_message'.i18n,
              boldTexts: 'example@gmail.com',
            ),
          ),
          SizedBox(height: 32),
          PrimaryButton(
            label: 'continue'.i18n,
            onPressed: () {
              appRouter.push(CreatePassword(email: email));
            },
          ),
          SizedBox(height: 24),
          Center(
            child: AppTextButton(
              label: 'resend_email'.i18n,
              textColor: AppColors.black,
              onPressed: () {},
            ),
          )
        ],
      ),
    );
  }
}
