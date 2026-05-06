import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/utils/storage_utils.dart';
import 'package:path/path.dart' as p;

final reportIssueAttachmentBudgetProvider =
    Provider<ReportIssueAttachmentBudget>(
      (ref) => PlatformReportIssueAttachmentBudget(),
    );

typedef ReportIssueLogFileResolver = Future<File?> Function();

Future<File?> defaultReportIssueLogFileResolver() async {
  if (!PlatformUtils.isIOS) {
    return null;
  }

  return AppStorageUtils.flutterLogFile();
}

abstract interface class ReportIssueAttachmentBudget {
  Future<int> reservedBytes();
}

class PlatformReportIssueAttachmentBudget
    implements ReportIssueAttachmentBudget {
  static const int _maxArchivedLogBytes = 50 * 1024 * 1024;
  static const List<String> _configFiles = <String>[
    'config.json',
    'servers.json',
    'split-tunnel.json',
  ];

  final Future<Directory> Function() _appDirectoryResolver;
  final Future<String> Function() _logDirectoryResolver;
  final ReportIssueLogFileResolver _logFileResolver;

  PlatformReportIssueAttachmentBudget({
    Future<Directory> Function()? appDirectoryResolver,
    Future<String> Function()? logDirectoryResolver,
    ReportIssueLogFileResolver? logFileResolver,
  }) : _appDirectoryResolver =
           appDirectoryResolver ?? AppStorageUtils.getAppDirectory,
       _logDirectoryResolver =
           logDirectoryResolver ?? AppStorageUtils.getAppLogDirectory,
       _logFileResolver = logFileResolver ?? defaultReportIssueLogFileResolver;

  @override
  Future<int> reservedBytes() async {
    final parts = await Future.wait<int>(<Future<int>>[
      _configBytes(),
      _archivedLogBytes(),
      _separateLogBytes(),
    ]);
    return parts.fold<int>(0, (sum, value) => sum + value);
  }

  Future<int> _configBytes() async {
    try {
      final appDir = await _appDirectoryResolver();
      var total = 0;
      for (final fileName in _configFiles) {
        total += await _safeFileLength(File(p.join(appDir.path, fileName)));
      }
      return total;
    } catch (error, stackTrace) {
      appLogger.error(
        'Unable to measure report issue config attachments',
        error,
        stackTrace,
      );
      return 0;
    }
  }

  Future<int> _archivedLogBytes() async {
    try {
      // Submit compresses these logs as logs.zip. Raw bytes give a conservative estimate.
      final logDirPath = await _logDirectoryResolver();
      final logDir = Directory(logDirPath);
      if (!await logDir.exists()) {
        return 0;
      }

      var total = 0;
      await for (final entity in logDir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) {
          continue;
        }

        total += await _safeFileLength(entity);
        if (total >= _maxArchivedLogBytes) {
          return _maxArchivedLogBytes;
        }
      }
      return total;
    } catch (error, stackTrace) {
      appLogger.error(
        'Unable to measure report issue log archive',
        error,
        stackTrace,
      );
      return 0;
    }
  }

  Future<int> _separateLogBytes() async {
    try {
      final logFile = await _logFileResolver();
      if (logFile == null) {
        return 0;
      }
      return _safeFileLength(logFile);
    } catch (error, stackTrace) {
      appLogger.error(
        'Unable to measure report issue separate log attachment',
        error,
        stackTrace,
      );
      return 0;
    }
  }

  Future<int> _safeFileLength(File file) async {
    try {
      if (!await file.exists()) {
        return 0;
      }

      final length = await file.length();
      return length > 0 ? length : 0;
    } catch (error, stackTrace) {
      appLogger.error(
        'Unable to measure report issue attachment file',
        error,
        stackTrace,
      );
      return 0;
    }
  }
}
