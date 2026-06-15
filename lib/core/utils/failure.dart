import 'package:lantern/core/localization/i18n.dart';

class Failure {
  final String error;
  final String localizedErrorMessage;

  Failure({required this.error, required this.localizedErrorMessage});

  factory Failure.featureDisabled(String feature) => Failure(
        error: '$feature disabled for this build',
        localizedErrorMessage: 'feature_disabled_for_build'.i18n,
      );

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
