import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/utils/device_utils.dart';
import 'package:lantern/core/utils/storage_utils.dart';
import 'package:lantern/features/report_issue/models/report_issue_attachment.dart';
import 'package:lantern/features/report_issue/models/report_issue_attachment_rules.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

final reportIssueSubmitterProvider = Provider<ReportIssueSubmitter>(
  (ref) => ReportIssueSubmitter(ref.read(lanternServiceProvider)),
);

typedef ReportIssueDeviceInfoLoader = Future<(String, String)> Function();
typedef ReportIssueLogFileResolver = Future<File?> Function();

class ReportIssueSubmitter {
  final LanternService _lanternService;
  final ReportIssueDeviceInfoLoader _deviceInfoLoader;
  final ReportIssueLogFileResolver _logFileResolver;

  ReportIssueSubmitter(
    LanternService lanternService, {
    ReportIssueDeviceInfoLoader? deviceInfoLoader,
    ReportIssueLogFileResolver? logFileResolver,
  }) : _lanternService = lanternService,
       _deviceInfoLoader = deviceInfoLoader ?? DeviceUtils.getDeviceAndModel,
       _logFileResolver = logFileResolver ?? _defaultLogFileResolver;

  Future<Either<Failure, Unit>> submit({
    required String email,
    required String issueType,
    required String description,
    required List<ReportIssueAttachment> attachments,
  }) async {
    final validationError = ReportIssueAttachmentRules.validateAttachments(
      attachments,
      reservedBytes: await _reservedBytes(),
    );
    if (validationError != null) {
      return Left(
        Failure(error: validationError, localizedErrorMessage: validationError),
      );
    }

    final deviceInfo = await _deviceInfoLoader();
    final logFile = await _resolveLogFile();

    return _lanternService.reportIssue(
      email,
      issueType,
      description,
      deviceInfo.$1,
      deviceInfo.$2,
      logFile?.path ?? '',
      attachments,
    );
  }

  Future<int> _reservedBytes() async {
    final logFile = await _resolveLogFile();
    if (logFile == null) {
      return 0;
    }

    try {
      return await logFile.length();
    } catch (error, stackTrace) {
      appLogger.error(
        'Unable to measure report issue log file',
        error,
        stackTrace,
      );
      return 0;
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

  static Future<File?> _defaultLogFileResolver() async {
    if (!PlatformUtils.isIOS) {
      return null;
    }

    return AppStorageUtils.flutterLogFile();
  }
}
