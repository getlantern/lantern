import 'package:fpdart/src/either.dart';
import 'package:fpdart/src/unit.dart';
import 'package:lantern/core/models/private_server_status.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'private_server_notifier.g.dart';

@riverpod
class PrivateServerNotifier extends _$PrivateServerNotifier {
  @override
  FutureOr<void> build() {
    // Initialize any state or perform setup here
  }

  // Add methods to handle private server logic, e.g., fetching providers, etc.
  Future<Either<Failure, Unit>> digitalOcean() async {
    return ref.read(lanternServiceProvider).digitalOceanPrivateServer();
  }

  Future<Either<Failure, Unit>> setUserInput(String input) async {
    return ref.read(lanternServiceProvider).setUserInput(input: input);
  }

  Stream<PrivateServerStatus> watchPrivateServerLogs() {
    return ref.read(lanternServiceProvider).watchPrivateServerStatus();
  }
}
