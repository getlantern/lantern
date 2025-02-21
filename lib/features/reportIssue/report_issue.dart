import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_text_filed.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/base_screen.dart';

@RoutePage(name: 'ReportIssue')
class ReportIssue extends StatelessWidget {
  const ReportIssue({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'report_issue'.i18n,
      body: Column(
        children: <Widget>[
          AppTextFiled(

            hintText: 'email',
            prefixIcon: AppImagePaths.email,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value!.isEmpty) {
                return 'email_empty'.i18n;
              }
              return null;
            },

          ),
        ],
      ),
    );
  }
}
