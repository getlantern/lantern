import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:lantern/core/models/user.dart';
import 'package:lantern/core/services/app_purchase.dart';
import 'package:lantern/core/services/injection_container.dart' show sl;
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/core/services/purchase/pending_purchase_store.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/lantern/lantern_platform_service.dart';

PurchaseDetails _receipt(
  String id, {
  PurchaseStatus status = PurchaseStatus.purchased,
  bool confirmed = false,
}) => PurchaseDetails(
  purchaseID: id,
  productID: '1m_sub',
  transactionDate: '1000',
  status: status,
  verificationData: PurchaseVerificationData(
    localVerificationData: '',
    serverVerificationData: 'token-$id',
    source: 'test',
  ),
)..pendingCompletePurchase = !confirmed;

class _Store extends Fake implements InAppPurchase {
  final completions = <PurchaseDetails>[];

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completions.add(purchase);
  }
}

class _Storage extends LocalStorageService {
  final maps = <String, Map<String, String>>{};

  @override
  Future<Map<String, String>> getStringMap(String key) async =>
      Map.of(maps[key] ?? {});

  @override
  Future<void> setStringMap(String key, Map<String, String> value) async {
    maps[key] = Map.of(value);
  }
}

class _Backend extends Fake implements LanternPlatformService {
  _Backend({this.isPro = false});

  final bool isPro;
  final receipts = <String>[];

  @override
  Future<Either<Failure, UserResponseModel>> fetchUserData() async => right(
    UserResponseModel(
      legacyID: 1,
      legacyToken: 'token',
      emailConfirmed: true,
      success: true,
      legacyUserData: UserDataModel(userLevel: isPro ? 'pro' : ''),
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
  late PendingPurchaseStore pending;
  late List<PurchaseDetails> pastPurchases;
  late int queries;
  bool billing = true;

  AppPurchase build() => AppPurchase(
    inAppPurchase: store,
    pendingStore: pending,
    canUseBilling: () => billing,
    queryPastPurchases: () async {
      queries++;
      return pastPurchases;
    },
  );

  setUp(() async {
    store = _Store();
    final storage = _Storage();
    pending = PendingPurchaseStore(() => storage);
    pastPurchases = [];
    queries = 0;
    billing = true;
    // A checkout that was interrupted after its plan was saved.
    await pending.rememberForProduct(
      '1m_sub',
      planId: '1m-usd-10',
      couponCode: 'AFF20',
    );
  });

  tearDown(() => sl.reset());

  test('reports an unconfirmed purchase and completes it', () async {
    final backend = _Backend();
    sl.registerSingleton<LanternPlatformService>(backend);
    final receipt = _receipt('a');
    pastPurchases = [receipt];

    await build().reconcilePastPurchases();

    expect(backend.receipts, ['token-a:1m-usd-10:AFF20']);
    expect(store.completions, [receipt]);
  });

  test('skips confirmed and non-purchased receipts', () async {
    final backend = _Backend();
    sl.registerSingleton<LanternPlatformService>(backend);
    pastPurchases = [
      _receipt('confirmed', confirmed: true),
      _receipt('pending', status: PurchaseStatus.pending),
    ];

    await build().reconcilePastPurchases();

    expect(backend.receipts, isEmpty);
    expect(store.completions, isEmpty);
  });

  test('finalizes without reporting when the account is already Pro', () async {
    final backend = _Backend(isPro: true);
    sl.registerSingleton<LanternPlatformService>(backend);
    final receipt = _receipt('a');
    pastPurchases = [receipt];

    await build().reconcilePastPurchases();

    expect(backend.receipts, isEmpty);
    expect(store.completions, [receipt]);
  });

  test('runs once per launch', () async {
    sl.registerSingleton<LanternPlatformService>(_Backend());
    final purchases = build();

    await purchases.reconcilePastPurchases();
    await purchases.reconcilePastPurchases();

    expect(queries, 1);
  });

  test('does nothing when store billing is unavailable', () async {
    sl.registerSingleton<LanternPlatformService>(_Backend());
    billing = false;

    await build().reconcilePastPurchases();

    expect(queries, 0);
  });

  test('a failed query does not throw', () async {
    sl.registerSingleton<LanternPlatformService>(_Backend());
    final purchases = AppPurchase(
      inAppPurchase: store,
      pendingStore: pending,
      canUseBilling: () => true,
      queryPastPurchases: () async => throw Exception('billing down'),
    );

    await expectLater(purchases.reconcilePastPurchases(), completes);
  });

  group('playAccountIdFor', () {
    UserResponseModel user({int legacyID = 0, int userId = 0}) =>
        UserResponseModel(
          legacyID: legacyID,
          legacyToken: '',
          emailConfirmed: false,
          success: true,
          legacyUserData: UserDataModel(userId: userId),
        );

    test('uses the legacy user ID', () {
      expect(AppPurchase.playAccountIdFor(user(legacyID: 42, userId: 7)), '42');
    });

    test('falls back to the user data ID', () {
      expect(AppPurchase.playAccountIdFor(user(userId: 7)), '7');
    });

    test('is null before the user is known', () {
      expect(AppPurchase.playAccountIdFor(user()), isNull);
    });
  });
}
