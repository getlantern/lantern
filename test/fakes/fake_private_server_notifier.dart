import 'dart:convert';

import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/entity/private_server_entity.dart';
import 'package:lantern/features/private_server/provider/private_server_notifier.dart';

class FakePrivateServerNotifier extends PrivateServerNotifier {
  FakePrivateServerNotifier() : super();

  @override
  Future<Either<Failure, Unit>> googleCloud() async {
    state = state.copyWith(
      status: 'EventTypeAccounts',
      data: 'alice@example.com, bob@example.com',
      error: null,
    );
    return right(unit);
  }

  @override
  Future<Either<Failure, Unit>> setUserInput(
      PrivateServerInput input, String value) async {
    switch (input) {
      case PrivateServerInput.selectAccount:
        state = state.copyWith(
          status: 'EventTypeProjects',
          data: 'billing-main, sandbox',
          error: null,
        );
        break;
      case PrivateServerInput.selectProject:
        state = state.copyWith(
          status: 'EventTypeLocations',
          data: 'us-central1, europe-west1',
          error: null,
        );
        break;
      default:
        break;
    }
    return right(unit);
  }

  @override
  Future<Either<Failure, Unit>> startDeployment(
      String location, String serverName) async {
    state = state.copyWith(status: 'EventTypeProvisioningStarted', data: null);

    await Future.delayed(const Duration(milliseconds: 50));

    final fakeEntity = PrivateServerEntity(
      serverName: serverName,
      externalIp: '203.0.113.10',
      port: '443',
      accessToken: 'abc123',
      protocol: 'Vmess',
      serverCountryCode: 'US',
      serverLocationName: location,
      isJoined: false,
    );

    state = state.copyWith(
      status: 'EventTypeProvisioningCompleted',
      data: jsonEncode(fakeEntity.toJson()),
      error: null,
    );
    return right(unit);
  }
}
