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

  final issueKeys = const [
    'cannot_access_blocked_sites',
    'cannot_complete_purchase',
    'cannot_sign_in',
    'spinner_loads_endlessly',
    'slow',
    'cannot_link_device',
    'application_crashes',
    'other',
  ];

  String issueLabel(String key) => key.i18n;

  final Map<String, String> _radianceCanon = {
    'cannot_access_blocked_sites': 'Cannot access blocked sites',
    'cannot_complete_purchase': 'Cannot complete purchase',
    'cannot_sign_in': 'Cannot sign in',
    'spinner_loads_endlessly': 'Spinner loads endlessly',
    'slow': 'Slow',
    'cannot_link_device': 'Cannot link device',
    'application_crashes': 'Application crashes',
    'other': 'Other',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = GlobalKey<FormState>();
    final emailController = useTextEditingController();
    final descriptionController = useTextEditingController();
    final selectedIssueController = useTextEditingController();
    final isLoading = useState(false);
    final selectedIssueKey = useTextEditingController();

    Future<void> openIssueSelection(BuildContext context) async {
      showAppBottomSheet(
        context: context,
        title: 'select_an_issue'.i18n,
        builder: (context, scrollController) {
          return Expanded(
            child: RadioListView(
              scrollController: scrollController,
              items: issueKeys.map(issueLabel).toList(),
              onChanged: (String label) {
                final idx = issueKeys.indexWhere((k) => issueLabel(k) == label);
                if (idx >= 0) {
                  selectedIssueKey.text = issueKeys[idx];
                }
                Navigator.of(context).pop();
              },
              groupValue: selectedIssueKey.text.isEmpty
                  ? ''
                  : issueLabel(selectedIssueKey.text),
            ),
          );
        },
      );
    }

    Future<void> submitReport() async {
      final issueType = selectedIssueController.text.trim();
      final description = descriptionController.text.trim();

      final email = emailController.text.trim();
      if (email.isNotEmpty && !EmailValidator.validate(email)) {
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
        (failure) async {
          AppDialog.errorDialog(
            context: context,
            title: 'error_reporting_issue'.i18n,
            content: failure.localizedErrorMessage.isNotEmpty
                ? failure.localizedErrorMessage
                : 'unknown_error_occurred'.i18n,
          );
        },
        (_) {
          context.showSnackBar('Thanks for your feedback!');
          emailController.clear();
          selectedIssueKey.clear();
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
