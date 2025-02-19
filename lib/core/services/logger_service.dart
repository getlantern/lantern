import 'package:flutter_loggy/flutter_loggy.dart';
import 'package:loggy/loggy.dart';

final dbLogger = Loggy("DB-Logger");
final appLogger = Loggy("app-Logger");

void initLogger() {
  final logPrinter = PrettyDeveloperPrinter();

  Loggy.initLoggy(
    logPrinter: logPrinter,
    logOptions: const LogOptions(LogLevel.all),
    hierarchicalLogging: true
  );
  appLogger.debug("Logger initialized ✅");
}
