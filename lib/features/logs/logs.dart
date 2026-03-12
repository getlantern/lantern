import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/utils/storage_utils.dart';
import 'package:lantern/core/widgets/info_row.dart';
import 'package:lantern/core/widgets/loading_indicator.dart';
import 'package:lantern/features/logs/log_line.dart';
import 'package:lantern/features/logs/provider/diagnostic_log_provider.dart';
import 'package:lantern/lantern/lantern_platform_service.dart';
import 'package:share_plus/share_plus.dart';

const int _maxVisibleLogLines = 800;

@RoutePage(name: 'Logs')
class Logs extends ConsumerWidget {
  const Logs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logAsyncValue = ref.watch(diagnosticLogStreamProvider);

    Future<void> shareLogFile() async {
      try {
        if (Platform.isIOS) {
          final logFilesResult =
              await sl<LanternPlatformService>().diagnosticLogFiles();
          final logPaths = logFilesResult.match(
            (failure) {
              appLogger.error(
                "Error fetching iOS diagnostic log files: ${failure.error}",
              );
              return const <String>[];
            },
            (paths) => paths,
          );

          if (logPaths.isEmpty) {
            return;
          }

          await SharePlus.instance.share(
            ShareParams(
              title: 'logs'.i18n,
              text: 'logs_share_message'.i18n,
              files: logPaths.map(XFile.new).toList(growable: false),
            ),
          );
          return;
        }

        final logFile = await AppStorageUtils.appLogFile();
        await SharePlus.instance.share(
          ShareParams(
            title: 'logs'.i18n,
            text: 'logs_share_message'.i18n,
            files: [XFile(logFile.path)],
          ),
        );
      } catch (e) {
        appLogger.error("Error sharing log file: $e");
      }
    }

    return BaseScreen(
      title: 'Diagnostic Logs'.i18n,
      appBar: CustomAppBar(
        title: Text('Diagnostic Logs'.i18n),
        actionsPadding: EdgeInsets.only(right: 24.0),
        actions: [
          AppIconButton(
            onPressed: shareLogFile,
            path: AppImagePaths.upArrow,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InfoRow(
            text: 'cannot_view_logs'.i18n,
          ),
          const SizedBox(height: defaultSize),
          Expanded(
            child: Container(
              decoration: ShapeDecoration(
                color: context.bgElevated,
                shape: RoundedRectangleBorder(
                  side: BorderSide(width: 1, color: context.borderDefault),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: logAsyncValue.when(
                data: (logs) {
                  final visibleLogs = latestLogsForDisplay(logs);
                  if (visibleLogs.isEmpty) {
                    return Center(
                      child: Text(
                        'No logs yet',
                        style: AppTextStyles.logTextStyle,
                      ),
                    );
                  }
                  return ListView.builder(
                    // Keep chronological order on screen while anchoring the viewport
                    // at the newest entry by default.
                    reverse: true,
                    padding: const EdgeInsets.all(8.0),
                    itemCount: visibleLogs.length,
                    itemBuilder: (context, index) {
                      final reversedIndex = visibleLogs.length - 1 - index;
                      return LogLineWidget(line: visibleLogs[reversedIndex]);
                    },
                  );
                },
                loading: () => const Center(
                  child: LoadingIndicator(),
                ),
                error: (error, stack) => Center(
                  child: Text(
                    "Error: $error",
                    style: AppTextStyles.logTextStyle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

@visibleForTesting
List<String> latestLogsForDisplay(List<String> logs) {
  if (logs.length <= _maxVisibleLogLines) {
    return logs;
  }
  return logs.sublist(logs.length - _maxVisibleLogLines);
}

TextStyle getLogStyle(String logLine) {
  final base = AppTextStyles.logTextStyle;
  if (logLine.startsWith('DEBUG[')) return base.copyWith(color: Colors.teal);
  if (logLine.startsWith('INFO[')) return base.copyWith(color: Colors.blue);
  if (logLine.startsWith('WARN[')) return base.copyWith(color: Colors.orange);
  if (logLine.startsWith('ERROR[')) {
    return base.copyWith(color: Colors.redAccent);
  }
  return base;
}
