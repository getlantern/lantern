import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/logs/provider/diagnostic_log_provider.dart';
import 'package:lantern/core/utils/storage_utils.dart';
import 'package:lantern/core/widgets/info_row.dart';
import 'package:lantern/features/logs/log_line.dart';
import 'package:share_plus/share_plus.dart';

@RoutePage(name: 'Logs')
class Logs extends HookConsumerWidget {
  const Logs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logAsyncValue = ref.watch(diagnosticLogStreamProvider);

    final scrollController = useScrollController();

    // Scroll to bottom when new logs arrive
    void scrollToBottom() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollController.hasClients) {
          scrollController.jumpTo(scrollController.position.maxScrollExtent);
        }
      });
    }

    Future<void> shareLogFile() async {
      try {
        final logFile = await AppStorageUtils.appLogFile();
        await Share.shareXFiles(
          [XFile(logFile.path)],
          text: 'logs_share_message'.i18n,
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
            onPressed: () => {},
          ),
          Expanded(
            child: Container(
              decoration: ShapeDecoration(
                color: AppColors.black1,
                shape: RoundedRectangleBorder(
                  side: BorderSide(width: 1),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: logAsyncValue.when(
                data: (logs) {
                  scrollToBottom(); // scroll when logs update
                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(8.0),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      return LogLineWidget(line: logs[index]);
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(),
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
