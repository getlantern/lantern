import 'package:auto_route/auto_route.dart';
import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/utils/device_utils.dart';
import 'package:lantern/core/utils/storage_utils.dart';
import 'package:lantern/features/report_issue/provider/report_issue_draft_notifier.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

@RoutePage(name: 'ReportIssue')
class ReportIssue extends ConsumerStatefulWidget {
  final String? description;
  final String? type;

  const ReportIssue({super.key, this.description, this.type});

  @override
  ConsumerState<ReportIssue> createState() => _ReportIssueState();
}

class _ReportIssueState extends ConsumerState<ReportIssue> {
  GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  GlobalKey<FormFieldState<String>> _issueTypeFieldKey =
      GlobalKey<FormFieldState<String>>();

  late final TextEditingController _emailController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _issueTypeController;
  late final FocusNode _issueTypeFocusNode;

  String? _selectedIssue;

  List<String> get issueOptions => <String>[
    'cannot_complete_purchase'.i18n,
    'cannot_sign_in'.i18n,
    'spinner_loads_endlessly'.i18n,
    'cannot_access_blocked_sites'.i18n,
    'slow'.i18n,
    'cannot_link_devices'.i18n,
    'application_crashes'.i18n,
    'other'.i18n,
  ];

  @override
  void initState() {
    super.initState();

    ref
        .read(reportIssueDraftProvider.notifier)
        .seedFromRoute(
          description: widget.description,
          issueType: _resolveInitialIssueType(),
        );

    final draft = ref.read(reportIssueDraftProvider);
    _selectedIssue = draft.issueType.isEmpty ? null : draft.issueType;

    _emailController = TextEditingController(text: draft.email);
    _descriptionController = TextEditingController(text: draft.description);
    _issueTypeController = TextEditingController(text: _selectedIssue ?? '');
    _issueTypeFocusNode = FocusNode();

    _emailController.addListener(_syncEmailDraft);
    _descriptionController.addListener(_syncDescriptionDraft);
    _issueTypeController.addListener(_syncIssueSelection);
  }

  @override
  void dispose() {
    _emailController
      ..removeListener(_syncEmailDraft)
      ..dispose();
    _descriptionController
      ..removeListener(_syncDescriptionDraft)
      ..dispose();
    _issueTypeController
      ..removeListener(_syncIssueSelection)
      ..dispose();
    _issueTypeFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'report_an_issue'.i18n,
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              AppTextField(
                controller: _emailController,
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
              _IssueTypeField(
                fieldKey: _issueTypeFieldKey,
                controller: _issueTypeController,
                focusNode: _issueTypeFocusNode,
                options: issueOptions,
                selectedIssue: _selectedIssue,
                onSelected: _setSelectedIssue,
              ),
              const SizedBox(height: 16),
              AppTextField(
                fieldKey: const Key('report_issue.description'),
                controller: _descriptionController,
                hintText: '',
                label: 'issue_description'.i18n,
                prefixIcon: Icons.description_outlined,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                maxLines: 10,
              ),
              const SizedBox(height: size24),
              PrimaryButton(
                label: 'submit_issue_report'.i18n,
                isTaller: true,
                onPressed: submitReport,
              ),
              const SizedBox(height: size24),
            ],
          ),
        ),
      ),
    );
  }

  String? _resolveInitialIssueType() {
    if (widget.type == null) {
      return null;
    }

    try {
      return issueOptions[int.parse(widget.type.toString())];
    } catch (e) {
      appLogger.error("Error parsing issue type: $e");
      return null;
    }
  }

  void _syncEmailDraft() {
    ref.read(reportIssueDraftProvider.notifier).setEmail(_emailController.text);
  }

  void _syncDescriptionDraft() {
    ref
        .read(reportIssueDraftProvider.notifier)
        .setDescription(_descriptionController.text);
  }

  void _syncIssueSelection() {
    if (_selectedIssue == null || _issueTypeController.text == _selectedIssue) {
      return;
    }

    _issueTypeFieldKey.currentState?.didChange(null);
    _setSelectedIssue(null);
  }

  void _setSelectedIssue(String? issueType) {
    if (_selectedIssue == issueType) {
      return;
    }

    setState(() {
      _selectedIssue = issueType;
    });
    ref.read(reportIssueDraftProvider.notifier).setIssueType(issueType ?? '');
  }

  void _clearDraft() {
    ref.read(reportIssueDraftProvider.notifier).clear();
    _formKey.currentState?.reset();
    _emailController.clear();
    _descriptionController.clear();
    _issueTypeController.clear();
    _issueTypeFieldKey.currentState?.didChange(null);

    setState(() {
      _selectedIssue = null;
    });
  }

  Future<void> submitReport() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    hideKeyboard();

    final issueType = _selectedIssue ?? '';
    final email = _emailController.text.trim();
    final description = _descriptionController.text.trim();

    context.showLoadingDialog();
    appLogger.debug("Submitting issue report: $issueType, $description");
    final deviceInfo = await DeviceUtils.getDeviceAndModel();
    final device = deviceInfo.$1;
    final model = deviceInfo.$2;
    String logFilePath = "";

    try {
      if (PlatformUtils.isIOS) {
        logFilePath = (await AppStorageUtils.flutterLogFile()).path;
      }
    } catch (e, st) {
      // Don't block reporting if logs fail. Just report without logs
      appLogger.error("Unable to resolve log file: $e", st);
      logFilePath = "";
    }

    final result = await ref
        .read(lanternServiceProvider)
        .reportIssue(email, issueType, description, device, model, logFilePath);

    if (!mounted) {
      return;
    }

    result.fold(
      (failure) {
        context.hideLoadingDialog();
        AppDialog.errorDialog(
          context: context,
          title: 'error'.i18n,
          content: failure.localizedErrorMessage,
        );
        context.showSnackBar(failure.localizedErrorMessage);
      },
      (_) {
        context.hideLoadingDialog();
        context.showSnackBar('thanks_for_feedback'.i18n);
        _clearDraft();
      },
    );
  }
}

class _IssueTypeField extends StatelessWidget {
  final GlobalKey<FormFieldState<String>> fieldKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> options;
  final String? selectedIssue;
  final ValueChanged<String?> onSelected;

  const _IssueTypeField({
    required this.fieldKey,
    required this.controller,
    required this.focusNode,
    required this.options,
    required this.selectedIssue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text(
            'select_an_issue'.i18n,
            style: textTheme.labelLarge?.copyWith(color: context.textSecondary),
          ),
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, constraints) {
            return DropdownMenuFormField<String>(
              key: fieldKey,
              controller: controller,
              focusNode: focusNode,
              width: constraints.maxWidth,
              menuHeight: 320,
              initialSelection: selectedIssue,
              requestFocusOnTap: true,
              enableFilter: true,
              enableSearch: true,
              textInputAction: TextInputAction.next,
              textStyle: textTheme.bodyMedium?.copyWith(
                color: context.textPrimary,
              ),
              leadingIcon: Icon(
                Icons.error_outline,
                color: context.textPrimary,
              ),
              trailingIcon: Icon(
                Icons.arrow_drop_down,
                color: context.textPrimary,
              ),
              selectedTrailingIcon: Icon(
                Icons.arrow_drop_up,
                color: context.textPrimary,
              ),
              dropdownMenuEntries: options
                  .map(
                    (issue) =>
                        DropdownMenuEntry<String>(value: issue, label: issue),
                  )
                  .toList(),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'please_select_an_issue'.i18n;
                }
                return null;
              },
              onSelected: onSelected,
            );
          },
        ),
      ],
    );
  }
}
