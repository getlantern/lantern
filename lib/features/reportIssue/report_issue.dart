import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_field.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/radio_listview.dart';

@RoutePage(name: 'ReportIssue')
class ReportIssue extends HookConsumerWidget {
  final String? description;

  ReportIssue({
    super.key,
    this.description,
  });

  final issueOptions = <String>[
    'cannot_access_blocked_sites'.i18n,
    'cannot_complete_purchase'.i18n,
    'cannot_sign_in'.i18n,
    'discover_not_working'.i18n,
    'spinner_loads_endlessly'.i18n,
    'slow'.i18n,
    'cannot_link_devices'.i18n,
    'application_crashes'.i18n,
    'other'.i18n
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailController = useTextEditingController();
    final descriptionController = useTextEditingController();
    final selectedIssueController = useTextEditingController();

    return BaseScreen(
      title: 'report_issue'.i18n,
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            AppTextField(
              hintText: 'Email (optional)',
              label: 'Email',
              prefixIcon: AppImagePaths.email,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value!.isEmpty) {
                  return 'email_empty'.i18n;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'select_an_issue'.i18n,
              hintText: '',
              onTap: () => openIssueSelection(context),
              prefixIcon: Icons.error_outline,
              suffixIcon: Icons.arrow_drop_down,
              controller: selectedIssueController,
            ),
            const SizedBox(height: 16),
            // Issue description (text area) with an icon on the left side
            AppTextField(
              controller: descriptionController,
              hintText: '',
              label: 'Issue Description',
              prefixIcon: Icons.description_outlined,
              maxLines: 10,
            ),
            const SizedBox(height: size24),
            PrimaryButton(
              label: 'submit_issue_report'.i18n,
              onPressed: submitReport,
            ),
            const SizedBox(height: size24),
          ],
        ),
      ),
    );
  }

  Future<void> openIssueSelection(BuildContext context) async {
    // Navigate to a full-screen issue selection screen and wait for the selected option.
    showAppBottomSheet(
      context: context,
      title: 'select_an_issue'.i18n,
      builder: (context, scrollController) {
        return Expanded(
            child: RadioListView(
          scrollController: scrollController,
          items: issueOptions,
          onTap: _onIssueTap,
        ));
      },
    );
  }

  void submitReport() {
    // print('Email: ${emailController.text}');
    // print('Issue: ${selectedIssueController.value}');
    // print('Description: ${descriptionController.text}');
  }

  void _onIssueTap(String issueType) {}
}
