import 'package:auto_route/auto_route.dart';
import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/utils/device_utils.dart';
import 'package:lantern/core/utils/storage_utils.dart';
import 'package:lantern/core/widgets/radio_listview.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

@RoutePage(name: 'ReportIssue')
class ReportIssue extends StatefulHookConsumerWidget {
  final String? description;
  final String? type;

  const ReportIssue({
    super.key,
    this.description,
    this.type,
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
    'other'.i18n,
  ];

  @override
  Widget build(BuildContext context) {
    final emailController = useTextEditingController();
    final descriptionController =
        useTextEditingController(text: widget.description);
    String type = '';
    try {
      if (widget.type != null) {
        type = issueOptions[int.parse(widget.type.toString())];
      }
    } catch (e) {
      appLogger.error("Error parsing issue type: $e");
      type = '';
    }

    final selectedIssueController = useTextEditingController(text: type);
    final update = useValueListenable(selectedIssueController);
    final groupValue = useState('');

    reset() {
      appLogger.debug("Resetting form");
      formKey.currentState!.reset();
      emailController.clear();
      descriptionController.clear();
      selectedIssueController.clear();
    }

    useEffect(() {
      groupValue.value = update.text;
      if (groupValue.value.isNotEmpty) {
        formKey.currentState?.validate();
      }
      return null;
    }, [update]);

    return EnterKeyShortcut(
      onEnter: () {
        submitReport(
          formKey,
          emailController.text.trim(),
          selectedIssueController.text,
          descriptionController.text.trim(),
          reset,
        );
      },
      child: BaseScreen(
        title: 'report_an_issue'.i18n,
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                  autovalidateMode: AutovalidateMode.disabled,
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
                  label: 'issue_description'.i18n,
                  prefixIcon: Icons.description_outlined,
                  maxLines: 10,
                ),
                const SizedBox(height: size24),
                PrimaryButton(
                  label: 'submit_issue_report'.i18n,
                  onPressed: () => submitReport(
                    formKey,
                    emailController.text.trim(),
                    selectedIssueController.text,
                    descriptionController.text.trim(),
                    reset,
                  ),
                ),
                const SizedBox(height: size24),
              ],
            ),
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

    hideKeyboard();

    context.showLoadingDialog();
    appLogger.debug("Submitting issue report: $issueType, $description");
    final deviceInfo = await DeviceUtils.getDeviceAndModel();
    final device = deviceInfo.$1;
    final model = deviceInfo.$2;
    String logFilePath = "";

    try {
      if (PlatformUtils.isIOS) {
        logFilePath = (await AppStorageUtils.flutterLogFile()).path;
      } else {
        logFilePath =
            (await AppStorageUtils.appLogFile(createIfMissing: true)).path;
      }
    } catch (e, st) {
      // Don't block reporting if logs fail. Just report without logs
      appLogger.error("Unable to resolve log file: $e", st);
      logFilePath = "";
    }
    final result = await ref
        .read(lanternServiceProvider)
        .reportIssue(email, issueType, description, device, model, logFilePath);
    result.fold(
      (failure) {
        context.hideLoadingDialog();
        AppDialog.errorDialog(
            context: context,
            title: 'error'.i18n,
            content: failure.localizedErrorMessage);
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
