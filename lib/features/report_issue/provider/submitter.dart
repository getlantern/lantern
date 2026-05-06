import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/utils/device_utils.dart';
import 'package:lantern/features/report_issue/models/report_issue_attachment.dart';
import 'package:lantern/features/report_issue/models/report_issue_attachment_rules.dart';
import 'package:lantern/features/report_issue/provider/attachment_access.dart';
import 'package:lantern/features/report_issue/provider/attachment_budget.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

final reportIssueSubmitterProvider = Provider<ReportIssueSubmitter>(
  (ref) => ReportIssueSubmitter(
    ref.read(lanternServiceProvider),
    attachmentAccess: ref.read(reportIssueAttachmentAccessProvider),
    attachmentBudget: ref.read(reportIssueAttachmentBudgetProvider),
  ),
);

typedef ReportIssueDeviceInfoLoader = Future<(String, String)> Function();

class ReportIssueSubmitter {
  final LanternService _lanternService;
  final ReportIssueDeviceInfoLoader _deviceInfoLoader;
  final ReportIssueAttachmentAccess _attachmentAccess;
  final ReportIssueAttachmentBudget _attachmentBudget;
  final ReportIssueLogFileResolver _logFileResolver;

  ReportIssueSubmitter(
    LanternService lanternService, {
    ReportIssueDeviceInfoLoader? deviceInfoLoader,
    ReportIssueAttachmentAccess? attachmentAccess,
    ReportIssueAttachmentBudget? attachmentBudget,
    ReportIssueLogFileResolver? logFileResolver,
  }) : _lanternService = lanternService,
       _deviceInfoLoader = deviceInfoLoader ?? DeviceUtils.getDeviceAndModel,
       _attachmentAccess =
           attachmentAccess ?? PlatformReportIssueAttachmentAccess(),
       _attachmentBudget =
           attachmentBudget ?? PlatformReportIssueAttachmentBudget(),
       _logFileResolver = logFileResolver ?? defaultReportIssueLogFileResolver;

  Future<Either<Failure, Unit>> submit({
    required String email,
    required String issueType,
    required String description,
    required List<ReportIssueAttachment> attachments,
  }) async {
    final reservedBytes = await _attachmentBudget.reservedBytes();
    final validationError = ReportIssueAttachmentRulesUtils.validateAttachments(
      attachments,
      reservedBytes: reservedBytes,
    );
    if (validationError != null) {
      return Left(
        Failure(error: validationError, localizedErrorMessage: validationError),
      );
    }

    final deviceInfo = await _deviceInfoLoader();
    final logFile = await _resolveLogFile();

    try {
      return await _attachmentAccess.withAccess(
        attachments,
        () => _lanternService.reportIssue(
          email,
          issueType,
          description,
          deviceInfo.$1,
          deviceInfo.$2,
          logFile?.path ?? '',
          attachments,
        ),
      );
    } on ReportIssueAttachmentAccessException catch (error) {
      return Left(
        Failure(error: error.message, localizedErrorMessage: error.message),
      );
    }
  }

  Future<File?> _resolveLogFile() async {
    try {
      return await _logFileResolver();
    } catch (error, stackTrace) {
      appLogger.error(
        'Unable to resolve report issue log file',
        error,
        stackTrace,
      );
      return null;
    }
  }
}
