import 'dart:io';

import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/utils/storage_utils.dart';

typedef ReportIssueLogFileResolver = Future<File?> Function();

Future<File?> defaultReportIssueLogFileResolver() async {
  if (!PlatformUtils.isIOS) {
    return null;
  }

  return AppStorageUtils.flutterLogFile();
}
