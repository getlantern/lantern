import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/utils/storage_utils.dart';
import 'package:lantern/core/widgets/loading_indicator.dart';
import 'package:lantern/features/logs/log_line.dart';
import 'package:lantern/features/logs/provider/diagnostic_log_notifier.dart';
import 'package:share_plus/share_plus.dart';

const int _maxVisibleLogLines = 500;

@RoutePage(name: 'Logs')
class Logs extends ConsumerStatefulWidget {
  const Logs({super.key});

  @override
  ConsumerState<Logs> createState() => _LogsState();
}

class _LogsState extends ConsumerState<Logs> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool get _isAtBottom {
    if (!_scrollController.hasClients) return true;
    return _scrollController.offset <=
        _scrollController.position.minScrollExtent + 40;
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.minScrollExtent);
    }
  }

  Future<void> _shareLogFile() async {
    try {
      List<String> filePaths;
      if (Platform.isIOS) {
        filePaths = await ref
            .read(diagnosticLogProvider.notifier)
            .diagnosticLogFilePath();
        final flutterLogFile = await AppStorageUtils.flutterLogFile();
        filePaths.add(flutterLogFile.path);
      } else {
        filePaths = await AppStorageUtils.logsFilePaths();
      }

      appLogger.debug('Sharing log files: $filePaths');

      if (filePaths.isEmpty) {
        appLogger.error('No log files found to share');
        return;
      }

      final xFiles = (await Future.wait(
        filePaths.map((path) async {
          final file = File(path);
          final exists = await file.exists();
          appLogger.debug(
            'Log file $path exists=$exists size=${exists ? await file.length() : 0}',
          );
          if (!exists) {
            appLogger.debug('Skipping missing log file: $path');
            return null;
          }
          return XFile(path);
        }),
      ))
          .whereType<XFile>()
          .toList();

      if (xFiles.isEmpty) {
        appLogger.error('No existing log files found to share');
        return;
      }

      await SharePlus.instance.share(
        ShareParams(
          title: 'logs'.i18n,
          text: 'logs_share_message'.i18n,
          files: xFiles,

        ),
      );
    } catch (e) {
      appLogger.error('Error sharing log file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<String>>>(diagnosticLogProvider, (_, next) {
      if (next.hasValue && _isAtBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    final logAsyncValue = ref.watch(diagnosticLogProvider);

    return BaseScreen(
      title: 'Diagnostic Logs'.i18n,
      appBar: CustomAppBar(
        title: Text('Diagnostic Logs'.i18n),
        actionsPadding: EdgeInsets.only(right: 24.0),
        actions: [
          AppIconButton(
            onPressed: _shareLogFile,
            path: AppImagePaths.upArrow,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
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
                    controller: _scrollController,
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

