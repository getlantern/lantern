import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

@immutable
class ReportIssueAttachment {
  final String name;
  final String path;
  final String mimeType;
  final int sizeBytes;
  final String? securityScopedBookmark;

  const ReportIssueAttachment({
    required this.name,
    required this.path,
    required this.mimeType,
    required this.sizeBytes,
    this.securityScopedBookmark,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'path': path,
    'mimeType': mimeType,
    'sizeBytes': sizeBytes,
  };

  String get displayName {
    final candidate = name.trim().isEmpty ? path.trim() : name.trim();
    if (candidate.isEmpty) {
      return 'attachment';
    }
    return p.basename(candidate);
  }

  String get formattedSize {
    final bytes = sizeBytes;
    if (bytes <= 0) {
      return '0 B';
    }

    const kb = 1024;
    const mb = 1024 * 1024;

    if (bytes >= mb) {
      final value = bytes / mb;
      return '${_trimSize(value >= 10 ? value.toStringAsFixed(0) : value.toStringAsFixed(1))} MB';
    }

    if (bytes >= kb) {
      final value = bytes / kb;
      return '${_trimSize(value >= 10 ? value.toStringAsFixed(0) : value.toStringAsFixed(1))} KB';
    }

    return '$bytes B';
  }

  static String _trimSize(String value) {
    return value.endsWith('.0') ? value.substring(0, value.length - 2) : value;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is ReportIssueAttachment &&
        other.name == name &&
        other.path == path &&
        other.mimeType == mimeType &&
        other.sizeBytes == sizeBytes;
  }

  @override
  int get hashCode => Object.hash(name, path, mimeType, sizeBytes);
}
