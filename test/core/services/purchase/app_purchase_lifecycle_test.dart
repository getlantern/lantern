import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:lantern/core/models/user.dart';
import 'package:lantern/core/services/app_purchase.dart';
import 'package:lantern/core/services/injection_container.dart' show sl;
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/core/services/purchase/pending_purchase_store.dart';
import 'package:lantern/core/utils/country_code.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/core/utils/store_utils.dart';
import 'package:lantern/features/home/provider/country_code_notifier.dart';
import 'package:lantern/lantern/lantern_platform_service.dart';

final _product = ProductDetails(
  id: '1m_sub',
  title: 'Monthly',
  description: '',
  price: r'$1.00',
  rawPrice: 1,
  currencyCode: 'USD',
);

PurchaseDetails _receipt(PurchaseStatus status) =>
    PurchaseDetails(
        purchaseID: 'purchase-1',
        productID: _product.id,
        transactionDate: '1000',
        status: status,
        verificationData: PurchaseVerificationData(
          localVerificationData: '',
          serverVerificationData: 'receipt',
          source: 'test',
        ),
      )
      ..pendingCompletePurchase =
          status == PurchaseStatus.purchased ||
          status == PurchaseStatus.restored;

class _Store extends Fake implements InAppPurchase {
  final updates = StreamController<List<PurchaseDetails>>.broadcast();
  Future<void>? loadingProducts;
  Future<void>? restoring;
  int listeners = 0;
  int checkouts = 0;
  int restores = 0;
  final completions = <PurchaseDetails>[];

  @override
  Stream<List<PurchaseDetails>> get purchaseStream {
    listeners++;
    return updates.stream;
  }

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async {
    await loadingProducts;
    return ProductDetailsResponse(productDetails: [_product], notFoundIDs: []);
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    checkouts++;
    return true;
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restores++;
    await restoring;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completions.add(purchase);
  }
}

class _Storage extends LocalStorageService {
  final maps = <String, Map<String, String>>{};
  Future<void>? saving;

  @override
  Future<Map<String, String>> getStringMap(String key) async =>
      Map.of(maps[key] ?? {});

  @override
  Future<void> setStringMap(String key, Map<String, String> value) async {
    await saving;
    maps[key] = Map.of(value);
  }
}

class _Backend extends Fake implements LanternPlatformService {
  final receipts = <String>[];

  @override
  Future<Either<Failure, UserResponseModel>> fetchUserData() async => right(
    const UserResponseModel(
      legacyID: 1,
      legacyToken: 'token',
      emailConfirmed: true,
      success: true,
    ),
  );

  @override
  Future<Either<Failure, String>> acknowledgeInAppPurchase({
    required String purchaseToken,
    required String planId,
    String couponCode = '',
  }) async {
    receipts.add('$purchaseToken:$planId:$couponCode');
    return right('ok');
  }
}

void main() {
  late _Store store;
  late _Storage storage;
  late PendingPurchaseStore pending;
  late _Backend backend;
  late AppPurchase purchases;
  late ProviderContainer container;
  late List<String> errors;
  late List<PurchaseDetails> successes;

  setUp(() {
    CountryCode.update('');
    store = _Store();
    storage = _Storage();
    pending = PendingPurchaseStore(() => storage);
    backend = _Backend();
    purchases = AppPurchase(
      inAppPurchase: store,
      pendingStore: pending,
      canUseBilling: () =>
          resolvePlayBillingAvailability(isAndroid: true, isStoreVersion: true),
    );
    sl.registerSingleton<LanternPlatformService>(backend);
    sl.registerSingleton<AppPurchase>(purchases);
    container = ProviderContainer();
    errors = [];
    successes = [];
  });

  tearDown(() async {
    container.dispose();
    await store.updates.close();
    await sl.reset();
    CountryCode.update('');
  });

  void changeCountry(String country) {
    container.read(countryCodeProvider.notifier).update(country);
  }

  Future<void> checkout() => purchases.startSubscription(
    plan: '1m-usd-10',
    couponCode: 'AFF20',
    onSuccess: successes.add,
    onError: errors.add,
  );

  for (final country in ['CN', 'RU', 'IR']) {
    testWidgets('$country update preserves an active checkout', (tester) async {
      await checkout();
      expect(store.checkouts, 1);
      changeCountry(country);

      final receipt = _receipt(PurchaseStatus.purchased);
      expect(await pending.planFor(receipt), '1m-usd-10');
      expect(await pending.couponFor(receipt), 'AFF20');
      store.updates.add([receipt]);
      await tester.pump();
      expect(backend.receipts, ['receipt:1m-usd-10:AFF20']);
      expect(store.completions, [receipt]);
      expect(successes, [receipt]);
      expect(errors, isEmpty);
      expect(await pending.planFor(receipt), isNull);
      expect(await pending.couponFor(receipt), isNull);
    });

    testWidgets('$country allows a new checkout', (tester) async {
      changeCountry(country);
      await checkout();

      expect(store.checkouts, 1);
      expect(store.listeners, 1);
      expect(errors, isEmpty);
      expect(
        await pending.planFor(_receipt(PurchaseStatus.purchased)),
        '1m-usd-10',
      );
    });
  }

  for (final status in [PurchaseStatus.canceled, PurchaseStatus.error]) {
    testWidgets('country update still delivers $status', (tester) async {
      await checkout();
      changeCountry('CN');
      final receipt = _receipt(status);
      if (status == PurchaseStatus.error) {
        receipt.error = IAPError(
          source: 'test',
          code: 'billing_error',
          message: 'Payment declined',
        );
      }
      store.updates.add([receipt]);
      await tester.pump();
      expect(errors, [
        status == PurchaseStatus.canceled
            ? 'Purchase canceled'
            : 'Payment declined',
      ]);
      expect(successes, isEmpty);
      expect(store.completions, isEmpty);
      expect(backend.receipts, isEmpty);
      expect(await pending.planFor(receipt), isNull);
      expect(await pending.couponFor(receipt), isNull);
    });
  }

  testWidgets('pending payment completes after a country update', (
    tester,
  ) async {
    await checkout();
    store.updates.add([_receipt(PurchaseStatus.pending)]);
    await tester.pump();
    expect(errors.single, contains('pending'));
    expect(successes, isEmpty);
    expect(store.completions, isEmpty);
    expect(backend.receipts, isEmpty);
    changeCountry('CN');
    final receipt = _receipt(PurchaseStatus.purchased);
    expect(await pending.planFor(receipt), '1m-usd-10');
    expect(await pending.couponFor(receipt), 'AFF20');
    store.updates.add([receipt]);
    await tester.pump();
    expect(errors.single, contains('pending'));
    expect(successes, [receipt]);
    expect(backend.receipts, ['receipt:1m-usd-10:AFF20']);
    expect(store.completions, [receipt]);
    expect(await pending.planFor(receipt), isNull);
    expect(await pending.couponFor(receipt), isNull);
  });

  testWidgets('country update preserves an in-flight restore', (tester) async {
    final restoring = Completer<void>();
    store.restoring = restoring.future;
    final started = purchases.restorePurchases(
      onSuccess: successes.add,
      onError: errors.add,
    );
    await tester.pump();
    expect(store.restores, 1);
    changeCountry('CN');
    final receipt = _receipt(PurchaseStatus.restored);
    store.updates.add([receipt]);
    restoring.complete();
    await started;
    await tester.pump();
    expect(store.completions, [receipt]);
    expect(successes, [receipt]);
    expect(errors, isEmpty);
  });

  for (final phase in ['product loading', 'metadata storage']) {
    testWidgets('country update during $phase allows checkout', (tester) async {
      final ready = Completer<void>();
      if (phase == 'product loading') {
        store.loadingProducts = ready.future;
      } else {
        storage.saving = ready.future;
      }
      final started = checkout();
      await tester.pump();
      changeCountry('CN');
      ready.complete();
      await started;
      expect(store.checkouts, 1);
      final receipt = _receipt(PurchaseStatus.purchased);
      store.updates.add([receipt]);
      await tester.pump();
      expect(backend.receipts, ['receipt:1m-usd-10:AFF20']);
      expect(store.completions, [receipt]);
      expect(successes, [receipt]);
      expect(errors, isEmpty);
      expect(await pending.planFor(receipt), isNull);
      expect(await pending.couponFor(receipt), isNull);
    });
  }

  testWidgets('country changes reuse the existing purchase listener', (
    tester,
  ) async {
    await checkout();
    purchases.init();
    changeCountry('CN');
    changeCountry('RU');
    changeCountry('IR');
    changeCountry('US');
    expect(store.listeners, 1);
    expect(store.updates.hasListener, isTrue);
    final receipt = _receipt(PurchaseStatus.purchased);
    store.updates.add([receipt]);
    await tester.pump();
    expect(backend.receipts, ['receipt:1m-usd-10:AFF20']);
    expect(store.completions, [receipt]);
    expect(successes, [receipt]);
    expect(errors, isEmpty);
  });
}
