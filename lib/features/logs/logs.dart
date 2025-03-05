import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/providers/ffi_provider.dart';
import 'package:lantern/core/providers/log_provider.dart';
import 'package:lantern/core/utils/log_utils.dart';
import 'package:share_plus/share_plus.dart';

@RoutePage(name: 'Logs')
class Logs extends HookConsumerWidget {
  const Logs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logAsyncValue = ref.watch(diagnosticLogProvider);

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
        final logDir = await getAppLogDirectory();
        final logFile = File("$logDir/lantern.log");

        if (!logFile.existsSync()) {
          throw Exception("Log file does not exist.");
        }

        await Share.shareXFiles(
          [XFile(logFile.path)],
          text: "Here are my diagnostic logs from Lantern.",
        );
      } catch (e) {
        debugPrint("Error sharing log file: $e");
      }
    }

    return BaseScreen(
      title: 'Diagnostic Logs'.i18n,
      appBar: CustomAppBar(
        title: 'Diagnostic Logs'.i18n,
        actionsPadding: EdgeInsets.only(right: 24.0),
        actions: [
          AppIconButton(
            onPressed: shareLogFile,
            path: AppImagePaths.headerShare,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    right: 8.0,
                  ), // Add spacing around the button
                  child: AppImage(
                    path: AppImagePaths.info,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Lantern cannot view your diagnostic logs unless you send them to us.',
                    style: AppTestStyles.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.black,
              child: logAsyncValue.when(
                data: (logs) {
                  scrollToBottom(); // Ensure we scroll when logs update
                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(8.0),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      return Text(
                        logs[index],
                        style: AppTestStyles.logTextStyle,
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Text(
                    "Error: $error",
                    style: AppTestStyles.logTextStyle,
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
