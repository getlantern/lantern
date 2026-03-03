import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/utils/storage_utils.dart';
import 'package:lantern/core/widgets/info_row.dart';
import 'package:lantern/core/widgets/loading_indicator.dart';
import 'package:lantern/features/logs/log_line.dart';
import 'package:lantern/features/logs/provider/diagnostic_log_provider.dart';
import 'package:share_plus/share_plus.dart';

const int _maxVisibleLogLines = 800;

@RoutePage(name: 'Logs')
class Logs extends HookConsumerWidget {
  const Logs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logAsyncValue = ref.watch(diagnosticLogStreamProvider);
    final scrollController = useScrollController();

    final pinnedToBottom = useState(true);
    final didInitialScroll = useState(false);

    useEffect(() {
      void listener() {
        if (!scrollController.hasClients) return;
        final pos = scrollController.position;

        // Treat small/non-scrollable content as pinned, so we keep following new logs.
        final canScrollMeaningfully = pos.maxScrollExtent > 64;
        final nearBottom =
            !canScrollMeaningfully || (pos.maxScrollExtent - pos.pixels) < 64;
        pinnedToBottom.value = nearBottom;
      }

      scrollController.addListener(listener);
      return () => scrollController.removeListener(listener);
    }, [scrollController]);

    void scrollToBottom() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!scrollController.hasClients) return;
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      });
    }

    void maybeScrollToBottom() {
      if (!pinnedToBottom.value) return;
      scrollToBottom();
    }

    Future<void> shareLogFile() async {
      try {
        if (Platform.isIOS) {
          final visibleLogs = latestLogsForDisplay(
              logAsyncValue.asData?.value ?? const <String>[]);
          if (visibleLogs.isEmpty) {
            return;
          }
          await SharePlus.instance.share(
            ShareParams(
              title: 'logs'.i18n,
              text: visibleLogs.join('\n'),
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
                  if (visibleLogs.isNotEmpty && !didInitialScroll.value) {
                    didInitialScroll.value = true;
                    scrollToBottom();
                  } else {
                    maybeScrollToBottom();
                  }
                  if (visibleLogs.isEmpty) {
                    return Center(
                      child: Text(
                        'No logs yet',
                        style: AppTextStyles.logTextStyle,
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(8.0),
                    itemCount: visibleLogs.length,
                    itemBuilder: (context, index) {
                      return LogLineWidget(line: visibleLogs[index]);
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
