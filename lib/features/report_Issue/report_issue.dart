import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/utils/device_utils.dart';
import 'package:lantern/core/utils/storage_utils.dart';
import 'package:lantern/core/widgets/radio_listview.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:email_validator/email_validator.dart';

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
    final formKey = GlobalKey<FormState>();
    final emailController = useTextEditingController();
    final descriptionController = useTextEditingController();
    final selectedIssueController = useTextEditingController();
    final isLoading = useState(false);

    Future<void> openIssueSelection(BuildContext context) async {
      showAppBottomSheet(
        context: context,
        title: 'select_an_issue'.i18n,
        builder: (context, scrollController) {
          return Expanded(
            child: RadioListView(
              scrollController: scrollController,
              items: issueOptions,
              onChanged: (String issueType) {
                selectedIssueController.text = issueType;
                Navigator.of(context).pop(issueType);
              },
              groupValue: '',
            ),
          );
        },
      );
    }

    Future<void> submitReport() async {
      final email = emailController.text.trim();
      final issueType = selectedIssueController.text.trim();
      final description = descriptionController.text.trim();

      if (!EmailValidator.validate(email)) {
        context.showSnackBar('Please enter a valid email address');
        return;
      }
      if (issueType.isEmpty) {
        context.showSnackBar('Please select an issue type');
        return;
      }
      if (description.isEmpty) {
        context.showSnackBar('Please enter a description of the issue');
        return;
      }

      isLoading.value = true;

      final logFile = await AppStorageUtils.appLogFile();
      final deviceInfo = await DeviceUtils.getDeviceAndModel();
      final device = deviceInfo.$1;
      final model = deviceInfo.$2;

      final result = await ref.read(lanternServiceProvider).reportIssue(
            email,
            issueType,
            description,
            device,
            model,
            logFile.path,
          );

      isLoading.value = false;

      result.fold(
        (failure) =>
            context.showSnackBar('Failed: ${failure.localizedErrorMessage}'),
        (_) {
          context.showSnackBar('Thanks for your feedback!');
          emailController.clear();
          selectedIssueController.clear();
          descriptionController.clear();
        },
      );
    }

    return BaseScreen(
      title: 'report_issue'.i18n,
      body: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            children: <Widget>[
              AppTextField(
                controller: emailController,
                hintText: 'Email (optional)',
                label: 'Email',
                prefixIcon: AppImagePaths.email,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value != null &&
                      value.isNotEmpty &&
                      !EmailValidator.validate(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: selectedIssueController,
                label: 'select_an_issue'.i18n,
                hintText: '',
                onTap: () => openIssueSelection(context),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Please select an issue'
                    : null,
                prefixIcon: Icons.error_outline,
                suffixIcon: Icons.arrow_drop_down,
              ),
              const SizedBox(height: 16),
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
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  await submitReport();
                },
              ),
              const SizedBox(height: size24),
            ],
          ),
        ),
      ),
    );
  }
}
