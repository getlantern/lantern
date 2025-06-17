import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/models/private_server_status.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/services/logger_service.dart';

part 'private_server_notifier.g.dart';

@riverpod
class PrivateServerNotifier extends _$PrivateServerNotifier {
  @override
  PrivateServerStatus build() {
    // Initialize any state or perform setup here
    watchPrivateServerLogs().listen(_handleStatus);
    return PrivateServerStatus(status: 'initial', data: null, error: null);
  }

  // Add methods to handle private server logic, e.g., fetching providers, etc.
  Future<Either<Failure, Unit>> digitalOcean() async {
    return ref.read(lanternServiceProvider).digitalOceanPrivateServer();
  }

  Future<Either<Failure, Unit>> setUserInput(
      PrivateServerInput method, String input) async {
    return ref.read(lanternServiceProvider).setUserInput(
          methodType: method,
          input: input,
        );
  }

  Future<Either<Failure, Unit>> startDeployment(String location,String serverName) async {
    return ref.read(lanternServiceProvider).startDeployment(location: location,serverName: serverName);
  }

  Future<Either<Failure, Unit>> cancelDeployment() async {
    return ref.read(lanternServiceProvider).cancelDeployment();
  }

  Future<Either<Failure, Unit>> setCert(String fingerprint) async {
    return ref.read(lanternServiceProvider).setCert(fingerprint: fingerprint);
  }

  Stream<PrivateServerStatus> watchPrivateServerLogs() {
    return ref.read(lanternServiceProvider).watchPrivateServerStatus();
  }

  void _handleStatus(PrivateServerStatus status) {
    appLogger.info("Private server status changed: ${status.status}");
    switch (status.status) {
      case 'openBrowser':
        final url = status.data ?? '';
        if (url.isEmpty) {
          // you could also expose this as part of your state
          // e.g. state = AsyncValue.error('…');
          // but here we’ll just show a snackbar
          // you’ll need a BuildContext – see note below
          state = PrivateServerStatus(
            status: 'error',
            error: 'private_server_setup_error',
          );
          return;
        }
        state = status;
        break;
      case 'EventTypeAccounts':
        final accounts = status.data;
        appLogger.info("Received accounts: $accounts");
        state = status;
        break;
      case 'EventTypeProjects':
        final accounts = status.data;
        appLogger.info("Received projects: $accounts");
        state = status;
        break;
      case 'EventTypeLocations':
        final locations = status.data;
        appLogger.info("Received location: $locations");
        state = status;
        break;
      default:
        state = status;
    }
  }
}
