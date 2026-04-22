import 'package:flutter/foundation.dart';

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

  factory ReportIssueAttachment.fromJson(Map<String, dynamic> json) {
    return ReportIssueAttachment(
      name: json['name'] as String? ?? '',
      path: json['path'] as String? ?? '',
      mimeType: json['mimeType'] as String? ?? '',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      securityScopedBookmark: _bookmarkFromJson(json),
    );
  }

  static String? _bookmarkFromJson(Map<String, dynamic> json) {
    final bookmark = (json['securityScopedBookmark'] as String?)?.trim();
    if (bookmark == null || bookmark.isEmpty) {
      return null;
    }
    return bookmark;
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
