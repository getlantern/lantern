import 'package:auto_route/auto_route.dart';
import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/utils/device_utils.dart';
import 'package:lantern/core/widgets/radio_listview.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

@RoutePage(name: 'ReportIssue')
class ReportIssue extends StatefulHookConsumerWidget {
  final String? description;

  const ReportIssue({
    super.key,
    this.description,
  });

  @override
  ConsumerState<ReportIssue> createState() => _ReportIssueState();
}

class _ReportIssueState extends ConsumerState<ReportIssue> {
  final formKey = GlobalKey<FormState>();

  final issueOptions = <String>[
    'cannot_access_blocked_sites'.i18n,
    'cannot_complete_purchase'.i18n,
    'cannot_sign_in'.i18n,
    'spinner_loads_endlessly'.i18n,
    'slow'.i18n,
    'cannot_link_devices'.i18n,
    'application_crashes'.i18n,
    'other'.i18n
  ];

  @override
  Widget build(BuildContext context) {
    final emailController = useTextEditingController();
    final descriptionController = useTextEditingController();
    final selectedIssueController = useTextEditingController();
    final update = useValueListenable(selectedIssueController);
    final groupValue = useState('');

    reset() {
      emailController.clear();
      descriptionController.clear();
      selectedIssueController.clear();
      groupValue.value = '';
      formKey.currentState?.reset();
    }

    useEffect(() {
      groupValue.value = update.text;
      return null;
    }, [update]);

    return BaseScreen(
      title: 'report_issue'.i18n,
      body: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            children: <Widget>[
              AppTextField(
                controller: emailController,
                hintText: 'email_optional'.i18n,
                label: 'email'.i18n,
                prefixIcon: AppImagePaths.email,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value != null &&
                      value.isNotEmpty &&
                      !EmailValidator.validate(value)) {
                    return 'please_enter_valid_email'.i18n;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: selectedIssueController,
                label: 'select_an_issue'.i18n,
                hintText: '',
                onTap: () => openIssueSelection(
                    selectedIssueController, groupValue.value),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'please_select_an_issue'.i18n
                    : null,
                prefixIcon: Icons.error_outline,
                suffixIcon: Icons.arrow_drop_down,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: descriptionController,
                hintText: '',
                label: 'please_enter_issue_description'.i18n,
                prefixIcon: Icons.description_outlined,
                maxLines: 10,
              ),
              const SizedBox(height: size24),
              PrimaryButton(
                label: 'submit_issue_report'.i18n,
                onPressed: () => submitReport(
                  formKey,
                  emailController.text.trim(),
                  groupValue.value,
                  descriptionController.text.trim(),
                  reset,
                ),
              ),
              const SizedBox(height: size24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> openIssueSelection(
      TextEditingController selectedIssueController, String groupValue) async {
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
              context.pop();
            },
            groupValue: groupValue,
          ),
        );
      },
    );
  }

  Future<void> submitReport(GlobalKey<FormState> formKey, String email,
      String issueType, String description, Function() reset) async {
    if (!formKey.currentState!.validate()) return;

    //hideKeyboard();
    context.showLoadingDialog();
    appLogger
        .debug("Submitting issue report: $email, $issueType, $description");
    final deviceInfo = await DeviceUtils.getDeviceAndModel();
    final device = deviceInfo.$1;
    final model = deviceInfo.$2;

    final result = await ref
        .read(lanternServiceProvider)
        .reportIssue(email, issueType, description, device, model, "");
    result.fold(
      (failure) {
        context.hideLoadingDialog();
        context.showSnackBar(failure.localizedErrorMessage);
      },
      (_) {
        context.hideLoadingDialog();
        context.showSnackBar('thanks_for_feedback'.i18n);
        reset.call();
      },
    );
  }
}
