import 'dart:convert';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/report_issue/models/report_issue_attachment.dart';
import 'package:lantern/features/report_issue/models/report_issue_attachment_rules.dart';
import 'package:path/path.dart' as p;

final reportIssueAttachmentPickerProvider =
    Provider<ReportIssueAttachmentPicker>(
      (ref) => PlatformReportIssueAttachmentPicker(),
    );

abstract interface class ReportIssueAttachmentPicker {
  bool get supportsDesktopDropTarget;

  Future<List<ReportIssueAttachment>> pickImages();

  Future<List<ReportIssueAttachment>> loadDroppedFiles(Iterable<XFile> files);
}

class PlatformReportIssueAttachmentPicker
    implements ReportIssueAttachmentPicker {
  static final List<XTypeGroup> _acceptedTypeGroups = <XTypeGroup>[
    XTypeGroup(
      label: 'Images',
      extensions: ReportIssueAttachmentRulesUtils.allowedExtensions,
    ),
  ];

  @override
  bool get supportsDesktopDropTarget => PlatformUtils.isDesktop;

  @override
  Future<List<ReportIssueAttachment>> pickImages() async {
    try {
      final files = await openFiles(acceptedTypeGroups: _acceptedTypeGroups);
      return _load(files);
    } catch (error, stackTrace) {
      appLogger.error(
        'Unable to select report issue attachments',
        error,
        stackTrace,
      );
      throw ReportIssueAttachmentPickerException(
        ReportIssueAttachmentRulesUtils.unreadableAttachmentMessage,
      );
    }
  }

  @override
  Future<List<ReportIssueAttachment>> loadDroppedFiles(
    Iterable<XFile> files,
  ) async {
    try {
      return _load(files);
    } catch (error, stackTrace) {
      appLogger.error(
        'Unable to load dropped report issue attachments',
        error,
        stackTrace,
      );
      throw ReportIssueAttachmentPickerException(
        ReportIssueAttachmentRulesUtils.unreadableAttachmentMessage,
      );
    }
  }

  Future<List<ReportIssueAttachment>> _load(Iterable<XFile> files) async {
    final attachments = <ReportIssueAttachment>[];
    for (final file in files) {
      final attachment = await _toAttachment(file);
      if (attachment != null) {
        attachments.add(attachment);
      }
    }
    return attachments;
  }

  Future<ReportIssueAttachment?> _toAttachment(XFile file) {
    return _withScopedAccess(file, () async {
      final path = file.path.trim();
      if (path.isEmpty) {
        return null;
      }

      final name = file.name.trim().isEmpty
          ? p.basename(path)
          : file.name.trim();
      final size = await file.length();
      final mimeType = ReportIssueAttachmentRulesUtils.canonicalMimeType(
        name: name,
        path: path,
        mimeType: file.mimeType ?? '',
      );
      final securityScopedBookmark = _securityScopedBookmark(file);

      return ReportIssueAttachment(
        name: name,
        path: path,
        mimeType: mimeType ?? file.mimeType ?? '',
        sizeBytes: size,
        securityScopedBookmark: securityScopedBookmark,
      );
    });
  }

  String? _securityScopedBookmark(XFile file) {
    if (!Platform.isMacOS || file is! DropItem) {
      return null;
    }

    final bookmark = file.extraAppleBookmark;
    if (bookmark == null || bookmark.isEmpty) {
      return null;
    }

    return base64Encode(bookmark);
  }

  Future<T> _withScopedAccess<T>(XFile file, Future<T> Function() read) async {
    if (!Platform.isMacOS || file is! DropItem) {
      return read();
    }

    final bookmark = file.extraAppleBookmark;
    if (bookmark == null || bookmark.isEmpty) {
      return read();
    }

    final granted = await DesktopDrop.instance
        .startAccessingSecurityScopedResource(bookmark: bookmark);

    try {
      return await read();
    } finally {
      if (granted) {
        await DesktopDrop.instance.stopAccessingSecurityScopedResource(
          bookmark: bookmark,
        );
      }
    }
  }
}

class ReportIssueAttachmentPickerException implements Exception {
  final String message;

  const ReportIssueAttachmentPickerException(this.message);

  @override
  String toString() => message;
}
