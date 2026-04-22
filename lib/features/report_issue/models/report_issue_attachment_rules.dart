import 'package:lantern/features/report_issue/models/report_issue_attachment.dart';
import 'package:path/path.dart' as p;

class ReportIssueAttachmentRules {
  static const int maxCount = 3;
  static const int maxTotalBytes = 15 * 1024 * 1024;

  static const String sectionLabel = 'Add screenshots';
  static const String helperText = 'PNG, JPG, or GIF — 15 MB max total';
  static const String uploadLabel = 'Add images';

  static const String unsupportedTypeMessage =
      'Only PNG, JPG, and GIF images are supported.';
  static const String tooManyAttachmentsMessage =
      'You can attach up to 3 images.';
  static const String totalSizeExceededMessage =
      'Attachments must stay under 15 MB total.';
  static const String duplicateAttachmentMessage =
      'That image is already attached.';
  static const String unreadableAttachmentMessage =
      'We could not read one of those files.';

  static const Map<String, String> _mimeTypesByExtension = <String, String>{
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'gif': 'image/gif',
  };

  static List<String> get allowedExtensions =>
      List<String>.unmodifiable(_mimeTypesByExtension.keys);

  static int totalBytes(Iterable<ReportIssueAttachment> attachments) {
    return attachments.fold<int>(
      0,
      (sum, attachment) => sum + attachment.sizeBytes,
    );
  }

  static String? validateAttachments(
    Iterable<ReportIssueAttachment> attachments, {
    int reservedBytes = 0,
  }) {
    final items = attachments.toList(growable: false);
    if (items.length > maxCount) {
      return tooManyAttachmentsMessage;
    }

    for (final attachment in items) {
      if (!isSupported(attachment)) {
        return unsupportedTypeMessage;
      }
    }

    if (reservedBytes + totalBytes(items) > maxTotalBytes) {
      return totalSizeExceededMessage;
    }

    return null;
  }

  static bool isSupported(ReportIssueAttachment attachment) {
    return canonicalMimeType(
          name: attachment.name,
          path: attachment.path,
          mimeType: attachment.mimeType,
        ) !=
        null;
  }

  static String? canonicalMimeType({
    required String name,
    required String path,
    required String mimeType,
  }) {
    final normalizedMime = mimeType.trim().toLowerCase();
    if (_mimeTypesByExtension.containsValue(normalizedMime)) {
      return normalizedMime;
    }

    final ext = extensionFor(name.isNotEmpty ? name : path);
    return ext == null ? null : _mimeTypesByExtension[ext];
  }

  static String? extensionFor(String source) {
    final ext = p.extension(source).toLowerCase();
    if (ext.isEmpty) {
      return null;
    }
    return ext.substring(1);
  }

  static String displayName(ReportIssueAttachment attachment) {
    final candidate = attachment.name.trim().isEmpty
        ? attachment.path.trim()
        : attachment.name.trim();
    if (candidate.isEmpty) {
      return 'attachment';
    }
    return p.basename(candidate);
  }

  static String formatSize(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }

    const kb = 1024;
    const mb = 1024 * 1024;

    if (bytes >= mb) {
      final value = bytes / mb;
      return '${_trim(value >= 10 ? value.toStringAsFixed(0) : value.toStringAsFixed(1))} MB';
    }

    if (bytes >= kb) {
      final value = bytes / kb;
      return '${_trim(value >= 10 ? value.toStringAsFixed(0) : value.toStringAsFixed(1))} KB';
    }

    return '$bytes B';
  }

  static String _trim(String value) {
    return value.endsWith('.0') ? value.substring(0, value.length - 2) : value;
  }
}
