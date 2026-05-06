import 'dart:convert';
import 'dart:collection';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/report_issue/models/report_issue_attachment.dart';
import 'package:lantern/features/report_issue/models/report_issue_attachment_rules.dart';

final reportIssueAttachmentAccessProvider =
    Provider<ReportIssueAttachmentAccess>(
      (ref) => PlatformReportIssueAttachmentAccess(),
    );

typedef ReportIssueBookmarkAccessStarter =
    Future<bool> Function(String bookmark);
typedef ReportIssueBookmarkAccessStopper =
    Future<void> Function(String bookmark);

abstract interface class ReportIssueAttachmentAccess {
  Future<T> withAccess<T>(
    List<ReportIssueAttachment> attachments,
    Future<T> Function() action,
  );
}

class PlatformReportIssueAttachmentAccess
    implements ReportIssueAttachmentAccess {
  final ReportIssueBookmarkAccessStarter _startAccess;
  final ReportIssueBookmarkAccessStopper _stopAccess;

  PlatformReportIssueAttachmentAccess({
    ReportIssueBookmarkAccessStarter? startAccess,
    ReportIssueBookmarkAccessStopper? stopAccess,
  }) : _startAccess = startAccess ?? _defaultStartAccess,
       _stopAccess = stopAccess ?? _defaultStopAccess;

  @override
  Future<T> withAccess<T>(
    List<ReportIssueAttachment> attachments,
    Future<T> Function() action,
  ) async {
    if (!Platform.isMacOS) {
      return action();
    }

    final bookmarks = LinkedHashSet<String>.from(
      attachments
          .map((attachment) => attachment.securityScopedBookmark?.trim() ?? '')
          .where((bookmark) => bookmark.isNotEmpty),
    );
    if (bookmarks.isEmpty) {
      return action();
    }

    final grantedBookmarks = <String>[];

    try {
      for (final bookmark in bookmarks) {
        final granted = await _startAccess(bookmark);
        if (!granted) {
          throw ReportIssueAttachmentAccessException(
            ReportIssueAttachmentRulesUtils.unreadableAttachmentMessage,
          );
        }
        grantedBookmarks.add(bookmark);
      }

      return await action();
    } on ReportIssueAttachmentAccessException {
      rethrow;
    } catch (error, stackTrace) {
      appLogger.error(
        'Unable to access report issue attachments',
        error,
        stackTrace,
      );
      throw ReportIssueAttachmentAccessException(
        ReportIssueAttachmentRulesUtils.unreadableAttachmentMessage,
      );
    } finally {
      for (final bookmark in grantedBookmarks.reversed) {
        try {
          await _stopAccess(bookmark);
        } catch (error, stackTrace) {
          appLogger.error(
            'Unable to release report issue attachment access',
            error,
            stackTrace,
          );
        }
      }
    }
  }

  static Future<bool> _defaultStartAccess(String bookmark) {
    return DesktopDrop.instance.startAccessingSecurityScopedResource(
      bookmark: base64Decode(bookmark),
    );
  }

  static Future<void> _defaultStopAccess(String bookmark) {
    return DesktopDrop.instance.stopAccessingSecurityScopedResource(
      bookmark: base64Decode(bookmark),
    );
  }
}

class ReportIssueAttachmentAccessException implements Exception {
  final String message;

  const ReportIssueAttachmentAccessException(this.message);

  @override
  String toString() => message;
}
