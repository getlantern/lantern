import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/user.dart';
import 'package:lantern/core/services/app_purchase.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/features/auth/device_limit_flow.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';
import 'package:lantern/features/plans/provider/payment_notifier.dart';

/// Shared restore-purchase flow used by Settings and Plans. Drives the
/// platform restore, talks to the backend, and surfaces success / device-limit
/// / error dialogs in a single place.
mixin RestorePurchaseMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  Future<void> restorePurchaseFlow() async {
    if (!mounted) return;
    context.showLoadingDialog();
    try {
      await sl<AppPurchase>().restorePurchases(
        onSuccess: _onRestoredPurchase,
        onError: (error) {
          if (!mounted) return;
          context.hideLoadingDialog();
          sl<AppPurchase>().clearCallbacks();
          if (error.contains('No previous purchases found')) {
            AppDialog.noPurchaseFoundDialog(context: context);
            return;
          }
          _showRestoreError(error);
        },
      );
    } catch (e, st) {
      appLogger.error('Error initiating restore purchase flow: $e', st);
      if (mounted) context.hideLoadingDialog();
      sl<AppPurchase>().clearCallbacks();
      _showRestoreError(e.localizedDescription);
    }
  }

  Future<void> _onRestoredPurchase(PurchaseDetails purchaseDetails) async {
    sl<AppPurchase>().clearCallbacks();
    final purchaseToken =
        purchaseDetails.verificationData.serverVerificationData;
    if (purchaseToken.isEmpty) {
      appLogger.error(
        '[Restore] Empty server verification token for ${purchaseDetails.productID}',
      );
      if (mounted) context.hideLoadingDialog();
      _showRestoreError('Unable to restore purchase: missing receipt.');
      return;
    }
    if (!mounted) return;

    appLogger.info('Found the restore purchase calling restore subscription');
    final result = await ref
        .read(paymentProvider.notifier)
        .restoreInAppPurchase(purchaseToken: purchaseToken);

    await result.fold(
      (failure) async {
        appLogger.error(
          '[Restore] restoreInAppPurchase failed: ${failure.error}',
        );
        if (mounted) context.hideLoadingDialog();
        _showRestoreError(failure.localizedErrorMessage);
      },
      (restorePurchase) async {
        if (!mounted) return;

        /// Once the purchase is successfully restored, we need to fetch the
        /// latest user data to get the updated subscription status and linked
        /// devices.
        await ref.read(homeProvider.notifier).fetchUserData();
        if (!mounted) return;
        context.hideLoadingDialog();
        if (restorePurchase.status == 'ok' &&
            restorePurchase.devices.isNotEmpty) {
          appLogger.info(
            '[Restore] Account restored with ${restorePurchase.devices.length} linked device(s); showing device list',
          );
          _showRestoredDevicesDialog(restorePurchase.devices);
          return;
        }
        appLogger.info('[Restore] Account restored; showing success dialog');
        AppDialog.purchaseRestoredDialog(
          context: context,
          onPressed: () => appRouter.popUntilRoot(),
        );
      },
    );
  }

  void _showRestoredDevicesDialog(List<DeviceModel> devices) {
    startDeviceLimitFlow(devices, () async {
      if (!mounted) return;
      AppDialog.purchaseRestoredDialog(
        context: context,
        onPressed: () => appRouter.popUntilRoot(),
      );
    });
  }

  void _showRestoreError(String message) {
    appLogger.error('[Restore] $message');
    if (!mounted) return;
    AppDialog.errorDialog(
      context: context,
      title: 'error'.i18n,
      content: message,
    );
  }
}
