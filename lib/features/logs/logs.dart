import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/providers/ffi_provider.dart';
import 'package:lantern/core/providers/log_provider.dart';

@RoutePage(name: 'Logs')
class Logs extends HookConsumerWidget {
  const Logs({super.key});

  static const logTextStyle = TextStyle(
    color: Color(0xFFDEDFDF),
    fontSize: 10,
    fontFamily: 'IBM Plex Mono',
    fontWeight: FontWeight.w400,
    height: 1.30,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logAsyncValue = ref.watch(diagnosticLogProvider);
    return BaseScreen(
      title: 'logs'.i18n,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Below are the diagnostic logs:",
              style: logTextStyle,
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.black,
              child: logAsyncValue.when(
                data: (logs) => SingleChildScrollView(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    logs.join('\n'),
                    style: logTextStyle,
                  ),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) =>
                    Center(child: Text("Error: $error", style: logTextStyle)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
