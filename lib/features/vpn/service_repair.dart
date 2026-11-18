import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/lantern/lantern_core_service.dart';
import 'package:loader_overlay/loader_overlay.dart';

/// Offers to repair Lantern's Windows service after a connect failed with a
/// [ServiceUnavailableFailure]. Resolves true once the service is back, so
/// the caller can retry its connect. A failed repair is reported here; one
/// the user declined is not.
Future<bool> repairLanternService(
  BuildContext context,
  LanternCoreService lantern,
) async {
  final confirmed = await AppDialog.serviceUnavailableDialog(context: context);
  if (!confirmed || !context.mounted) return false;
  // The overlay is app-wide, so hide it through its controller rather than
  // this context, which may be gone by the time the repair returns.
  final overlay = context.loaderOverlay;
  overlay.show();
  final Either<Failure, Unit> result;
  try {
    result = await lantern.repairService();
  } finally {
    overlay.hide();
  }
  return result.fold((failure) {
    if (failure is ServiceRepairFailure && failure.cancelled) return false;
    if (context.mounted) {
      AppDialog.errorDialog(
        context: context,
        title: 'unable_to_connect'.i18n,
        content: failure.localizedErrorMessage,
      );
    }
    return false;
  }, (_) => true);
}
