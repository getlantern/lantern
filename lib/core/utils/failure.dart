import 'package:lantern/core/localization/i18n.dart';

class Failure {
  final String error;
  final String localizedErrorMessage;

  Failure({required this.error, required this.localizedErrorMessage});

  @override
  String toString() =>
      'Failure(error: $error, localizedErrorMessage: $localizedErrorMessage)';
}

class VpnConflictFailure extends Failure {
  VpnConflictFailure()
    : super(
        error: 'vpn_conflict',
        localizedErrorMessage: 'vpn_conflict_body'.i18n,
      );
}

/// A connect that failed because Lantern's Windows service isn't running, so
/// the app can offer to repair it.
class ServiceUnavailableFailure extends Failure {
  /// Starts lantern-core's error when the service needs repair.
  static const marker = 'lantern_service_unavailable';

  ServiceUnavailableFailure(String error)
    : super(
        error: error,
        localizedErrorMessage: 'lantern_service_unavailable_body'.i18n,
      );

  static bool matches(String error) => error.contains(marker);
}

/// A repair of Lantern's Windows service that didn't bring it back.
class ServiceRepairFailure extends Failure {
  static const _cancelledMarker = 'lantern_service_repair_cancelled';

  ServiceRepairFailure(String error)
    : super(
        error: error,
        localizedErrorMessage: 'lantern_service_repair_failed'.i18n,
      );

  /// The user declined Windows' permission prompt.
  bool get cancelled => error.contains(_cancelledMarker);
}
