import 'package:auto_route/auto_route.dart';
import 'package:cross_file/cross_file.dart';
import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/report_issue/models/report_issue_attachment.dart';
import 'package:lantern/features/report_issue/models/report_issue_attachment_rules.dart';
import 'package:lantern/features/report_issue/provider/report_issue_draft_notifier.dart';
import 'package:lantern/features/report_issue/provider/attachment_picker.dart';
import 'package:lantern/features/report_issue/provider/attachment_budget.dart';
import 'package:lantern/features/report_issue/provider/submitter.dart';
import 'package:lantern/features/report_issue/widgets/report_issue_attachment_dropzone.dart';

@RoutePage(name: 'ReportIssue')
class ReportIssue extends ConsumerStatefulWidget {
  final String? description;
  final String? type;

  const ReportIssue({super.key, this.description, this.type});

  @override
  ConsumerState<ReportIssue> createState() => _ReportIssueState();
}

class _ReportIssueState extends ConsumerState<ReportIssue> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey<FormFieldState<String>> _issueTypeFieldKey =
      GlobalKey<FormFieldState<String>>();

  late final TextEditingController _emailController;
  late final TextEditingController _descriptionController;

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

    final draft = ref.read(reportIssueDraftProvider);
    final initialIssueType = _resolveInitialIssueType();
    final seededDescription = _seededValue(
      draft.description,
      widget.description,
    );
    final seededIssueType = _seededValue(draft.issueType, initialIssueType);

    _selectedIssue = seededIssueType.isEmpty ? null : seededIssueType;

    _emailController = TextEditingController(text: draft.email);
    _descriptionController = TextEditingController(text: seededDescription);

    _emailController.addListener(_syncEmailDraft);
    _descriptionController.addListener(_syncDescriptionDraft);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(reportIssueDraftProvider.notifier)
          .seedFromRoute(
            description: widget.description,
            issueType: initialIssueType,
          );
    });
  }

  @override
  void dispose() {
    _emailController
      ..removeListener(_syncEmailDraft)
      ..dispose();
    _descriptionController
      ..removeListener(_syncDescriptionDraft)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(reportIssueDraftProvider);
    final attachmentPicker = ref.watch(reportIssueAttachmentPickerProvider);

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
              const SizedBox(height: 16),
              _AttachmentSection(
                attachments: draft.attachments,
                errorText: draft.attachmentError,
                enableDesktopDrop: attachmentPicker.supportsDesktopDropTarget,
                onAdd: _pickAttachments,
                onDrop: _handleDroppedFiles,
                onRemove: _removeAttachment,
              ),
              const SizedBox(height: size24),
              PrimaryButton(
                buttonKey: const Key('report_issue.submit_button'),
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
      appLogger.error('Error parsing issue type: $e');
      return null;
    }
  }

  String _seededValue(String currentValue, String? incomingValue) {
    if (currentValue.isNotEmpty) {
      return currentValue;
    }
    return incomingValue?.trim() ?? '';
  }

  void _syncEmailDraft() {
    ref.read(reportIssueDraftProvider.notifier).setEmail(_emailController.text);
  }

  void _syncDescriptionDraft() {
    ref
        .read(reportIssueDraftProvider.notifier)
        .setDescription(_descriptionController.text);
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

  Future<void> _pickAttachments() async {
    final notifier = ref.read(reportIssueDraftProvider.notifier);

    try {
      final attachments = await ref
          .read(reportIssueAttachmentPickerProvider)
          .pickImages();
      await _addAttachmentsToDraft(attachments);
    } on ReportIssueAttachmentPickerException catch (error) {
      notifier.setAttachmentError(error.message);
    } catch (error, stackTrace) {
      appLogger.error(
        'Unable to add report issue attachments',
        error,
        stackTrace,
      );
      notifier.setAttachmentError(
        ReportIssueAttachmentRulesUtils.unreadableAttachmentMessage,
      );
    }
  }

  Future<void> _handleDroppedFiles(List<XFile> files) async {
    final notifier = ref.read(reportIssueDraftProvider.notifier);

    try {
      final attachments = await ref
          .read(reportIssueAttachmentPickerProvider)
          .loadDroppedFiles(files);
      await _addAttachmentsToDraft(attachments);
    } on ReportIssueAttachmentPickerException catch (error) {
      notifier.setAttachmentError(error.message);
    } catch (error, stackTrace) {
      appLogger.error(
        'Unable to drop report issue attachments',
        error,
        stackTrace,
      );
      notifier.setAttachmentError(
        ReportIssueAttachmentRulesUtils.unreadableAttachmentMessage,
      );
    }
  }

  void _removeAttachment(ReportIssueAttachment attachment) {
    ref.read(reportIssueDraftProvider.notifier).removeAttachment(attachment);
  }

  Future<void> _addAttachmentsToDraft(
    List<ReportIssueAttachment> attachments,
  ) async {
    if (attachments.isEmpty) {
      return;
    }

    final reservedBytes = await ref
        .read(reportIssueAttachmentBudgetProvider)
        .reservedBytes();

    if (!mounted) {
      return;
    }

    ref
        .read(reportIssueDraftProvider.notifier)
        .addAttachments(attachments, reservedBytes: reservedBytes);
  }

  void _clearDraft() {
    ref.read(reportIssueDraftProvider.notifier).clear();
    _formKey.currentState?.reset();
    _emailController.clear();
    _descriptionController.clear();
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

    final draft = ref.read(reportIssueDraftProvider);
    final issueType = _selectedIssue ?? '';
    final email = _emailController.text.trim();
    final description = _descriptionController.text.trim();

    context.showLoadingDialog();
    appLogger.debug('Submitting issue report: $issueType, $description');

    final result = await ref
        .read(reportIssueSubmitterProvider)
        .submit(
          email: email,
          issueType: issueType,
          description: description,
          attachments: draft.attachments,
        );

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

class _AttachmentSection extends StatelessWidget {
  final List<ReportIssueAttachment> attachments;
  final String? errorText;
  final bool enableDesktopDrop;
  final VoidCallback onAdd;
  final Future<void> Function(List<XFile> files) onDrop;
  final ValueChanged<ReportIssueAttachment> onRemove;

  const _AttachmentSection({
    required this.attachments,
    required this.errorText,
    required this.enableDesktopDrop,
    required this.onAdd,
    required this.onDrop,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final helperStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: context.textTertiary);
    final errorStyle = helperStyle?.copyWith(color: context.statusErrorText);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text(
            ReportIssueAttachmentRulesUtils.sectionLabel,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: context.textSecondary),
          ),
        ),
        if (attachments.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          ...attachments.map(
            (attachment) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AttachmentTile(
                attachment: attachment,
                onRemove: () => onRemove(attachment),
              ),
            ),
          ),
        ] else
          const SizedBox(height: 8),
        ReportIssueAttachmentDropzone(
          label: ReportIssueAttachmentRulesUtils.uploadLabel,
          onTap: onAdd,
          onDrop: onDrop,
          enableDesktopDrop: enableDesktopDrop,
          enabled:
              attachments.length < ReportIssueAttachmentRulesUtils.maxCount,
          compact: attachments.isNotEmpty,
        ),
        const SizedBox(height: 8),
        Text(ReportIssueAttachmentRulesUtils.helperText, style: helperStyle),
        if (errorText != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(errorText!, style: errorStyle),
        ],
      ],
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  final ReportIssueAttachment attachment;
  final VoidCallback onRemove;

  const _AttachmentTile({required this.attachment, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('report_issue.attachment.${attachment.path}'),
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: context.bgElevated,
        borderRadius: defaultBorderRadius,
        border: Border.all(color: context.borderInput),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.image_outlined, color: context.textPrimary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    attachment.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  attachment.formattedSize,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: context.textTertiary),
                ),
              ],
            ),
          ),
          IconButton(
            key: Key('report_issue.remove.${attachment.path}'),
            icon: Icon(Icons.close, color: context.textSecondary),
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            padding: EdgeInsets.zero,
            onPressed: onRemove,
            tooltip: 'Remove ${attachment.displayName}',
          ),
        ],
      ),
    );
  }
}

class _IssueTypeField extends StatelessWidget {
  final GlobalKey<FormFieldState<String>> fieldKey;
  final List<String> options;
  final String? selectedIssue;
  final ValueChanged<String?> onSelected;

  const _IssueTypeField({
    required this.fieldKey,
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
        DropdownButtonFormField<String>(
          key: fieldKey,
          initialValue: selectedIssue,
          isExpanded: true,
          menuMaxHeight: 320,
          style: textTheme.bodyMedium?.copyWith(color: context.textPrimary),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: context.textPrimary,
          ),
          hint: const SizedBox.shrink(),
          decoration: InputDecoration(
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 16, right: 16),
              child: Align(
                alignment: Alignment.center,
                widthFactor: 1,
                heightFactor: 1,
                child: Icon(Icons.error_outline, color: context.textPrimary),
              ),
            ),
          ),
          items: options
              .map(
                (issue) =>
                    DropdownMenuItem<String>(value: issue, child: Text(issue)),
              )
              .toList(),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'please_select_an_issue'.i18n;
            }
            return null;
          },
          onChanged: onSelected,
        ),
      ],
    );
  }
}
