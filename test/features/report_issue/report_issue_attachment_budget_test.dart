import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/features/report_issue/provider/attachment_budget.dart';

void main() {
  group('PlatformReportIssueAttachmentBudget', () {
    test(
      'includes config files, archived logs, and the separate log file',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'report-issue-budget',
        );
        addTearDown(() => tempDir.deleteSync(recursive: true));

        final appDir = Directory('${tempDir.path}/app')
          ..createSync(recursive: true);
        final logDir = Directory('${tempDir.path}/logs')
          ..createSync(recursive: true);
        final nestedLogDir = Directory('${logDir.path}/nested')
          ..createSync(recursive: true);

        File(
          '${appDir.path}/config.json',
        ).writeAsBytesSync(List<int>.filled(32, 1));
        File(
          '${appDir.path}/servers.json',
        ).writeAsBytesSync(List<int>.filled(48, 2));
        File(
          '${logDir.path}/lantern.log',
        ).writeAsBytesSync(List<int>.filled(64, 3));
        File(
          '${nestedLogDir.path}/service.log',
        ).writeAsBytesSync(List<int>.filled(96, 4));
        final flutterLog = File('${tempDir.path}/flutter.log');
        flutterLog.writeAsBytesSync(List<int>.filled(128, 5));

        final budget = PlatformReportIssueAttachmentBudget(
          appDirectoryResolver: () async => appDir,
          logDirectoryResolver: () async => logDir.path,
          logFileResolver: () async => flutterLog,
        );

        expect(await budget.reservedBytes(), 368);
      },
    );
  });
}
