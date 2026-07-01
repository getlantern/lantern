import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/utils/storage_utils.dart';
import 'package:lantern/features/logs/log_exporter.dart';
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
    List<File> files = const [];
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

      files = await existingLogFiles(filePaths);
      if (files.isEmpty) {
        appLogger.error('No existing log files found to share');
        if (mounted) {
          context.showSnackBarError('No diagnostic log files found');
        }
        return;
      }

      final xFiles = files.map((file) => XFile(file.path)).toList();

      final result = await SharePlus.instance.share(
        ShareParams(
          title: 'logs'.i18n,
          text: 'logs_share_message'.i18n,
          files: xFiles,
        ),
      );
      if (!Platform.isWindows &&
          result.status == ShareResultStatus.unavailable &&
          mounted) {
        context.showSnackBarError('Unable to export diagnostic logs');
      }
    } catch (e, st) {
      appLogger.error('Error sharing log file', e, st);
      if (Platform.isWindows) {
        await _exportWindowsLogFiles(files);
        return;
      }
      if (mounted) {
        context.showSnackBarError('Unable to export diagnostic logs');
      }
    }
  }

  Future<void> _exportWindowsLogFiles(List<File> files) async {
    final location = await file_selector.getSaveLocation(
      acceptedTypeGroups: const [
        file_selector.XTypeGroup(label: 'Text files', extensions: ['txt']),
      ],
      suggestedName: diagnosticLogExportFileName(DateTime.now()),
      confirmButtonText: 'Export',
      canCreateDirectories: true,
    );
    if (location == null) {
      return;
    }

    final exported = await writeDiagnosticLogBundle(files, location.path);
    appLogger.info('Exported diagnostic logs to ${exported.path}');
    if (mounted) {
      context.showSnackBar(
        'Diagnostic logs exported to ${exported.path}',
        closeButton: true,
      );
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
          AppIconButton(onPressed: _shareLogFile, path: AppImagePaths.upArrow),
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
                loading: () => const Center(child: LoadingIndicator()),
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
