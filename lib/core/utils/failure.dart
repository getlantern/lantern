import 'package:lantern/core/localization/i18n.dart';

class Failure {
  final String error;
  final String localizedErrorMessage;

  Failure({required this.error, required this.localizedErrorMessage});

  @override
  String toString() =>
      'Failure(error: $error, localizedErrorMessage: $localizedErrorMessage)';
}

/// Android's "Nearby devices" (local network) permission is denied.
class LocalNetworkDeniedFailure extends Failure {
  LocalNetworkDeniedFailure()
      : super(
          error: 'local_network_denied',
          localizedErrorMessage: 'local_network_denied_body'.i18n,
        );
}

class VpnConflictFailure extends Failure {
  VpnConflictFailure()
      : super(
          error: 'vpn_conflict',
          localizedErrorMessage: 'vpn_conflict_body'.i18n,
        );
}
