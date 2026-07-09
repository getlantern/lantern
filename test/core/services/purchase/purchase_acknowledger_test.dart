import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:lantern/core/services/purchase/purchase_acknowledger.dart';
import 'package:lantern/core/utils/failure.dart';

PurchaseDetails _purchase({
  String productID = '1y_sub',
  String purchaseID = 'txn-1',
  String receipt = 'server-receipt',
}) => PurchaseDetails(
  purchaseID: purchaseID,
  productID: productID,
  transactionDate: '1000',
  status: PurchaseStatus.purchased,
  verificationData: PurchaseVerificationData(
    localVerificationData: 'local',
    serverVerificationData: receipt,
    source: 'test',
  ),
);

Failure _failure() =>
    Failure(error: 'boom', localizedErrorMessage: 'boom');

/// Collects callback invocations so tests can assert exact counts.
class _Recorder {
  int success = 0;
  int error = 0;
  int acknowledged = 0;
}

void main() {
  late _Recorder rec;

  setUp(() => rec = _Recorder());

  /// Builds an acknowledger with sensible fakes; each collaborator is
  /// overridable per test.
  PurchaseAcknowledger build({
    required ReceiptAcknowledger acknowledgeReceipt,
    Future<bool> Function()? isAlreadyActive,
    List<Duration>? retryDelays,
    int? maxRetries,
  }) => PurchaseAcknowledger(
    acknowledgeReceipt: acknowledgeReceipt,
    resolvePlanId: (_) async => '1y-usd-10',
    resolveCouponCode: (_) async => '',
    retryKeyFor: (p) => p.purchaseID ?? p.productID,
    isAlreadyActive: isAlreadyActive ?? () async => false,
    onAcknowledged: (_) async => rec.acknowledged++,
    retryDelays: retryDelays ?? const [Duration(milliseconds: 5)],
    maxRetries: maxRetries,
  );

  test('confirms on the first try: finalizes and fires onSuccess once', () async {
    final ack = build(
      acknowledgeReceipt: ({required purchaseToken, required planId, required couponCode}) async =>
          right('ok'),
    );

    await ack.acknowledge(
      _purchase(),
      planId: '1y-usd-10',
      couponCode: '',
      onSuccess: (_) => rec.success++,
      onError: (_) => rec.error++,
    );

    expect(rec.acknowledged, 1);
    expect(rec.success, 1);
    expect(rec.error, 0);
  });

  test('backend error but account already active: finalizes as success', () async {
    final ack = build(
      acknowledgeReceipt: ({required purchaseToken, required planId, required couponCode}) async =>
          left(_failure()),
      isAlreadyActive: () async => true,
    );

    await ack.acknowledge(
      _purchase(),
      planId: '1y-usd-10',
      couponCode: '',
      onSuccess: (_) => rec.success++,
      onError: (_) => rec.error++,
    );

    expect(rec.acknowledged, 1);
    expect(rec.success, 1);
    expect(rec.error, 0);
  });

  test('transient failure then background-retry success', () async {
    var calls = 0;
    final ack = build(
      acknowledgeReceipt: ({required purchaseToken, required planId, required couponCode}) async {
        calls++;
        return calls == 1 ? left(_failure()) : right('ok');
      },
    );

    await ack.acknowledge(
      _purchase(),
      planId: '1y-usd-10',
      couponCode: '',
      onSuccess: (_) => rec.success++,
      onError: (_) => rec.error++,
    );

    // Initial attempt failed: user was told once, transaction not yet finalized.
    expect(rec.error, 1);
    expect(rec.acknowledged, 0);

    // Let the scheduled retry fire.
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(calls, 2);
    expect(rec.acknowledged, 1); // retry finalized the transaction
    expect(rec.success, 0); // background retries stay silent
    expect(rec.error, 1); // no second error surfaced
  });

  test('empty receipt is treated as a failure and surfaced once', () async {
    var receiptCalls = 0;
    final ack = build(
      acknowledgeReceipt: ({required purchaseToken, required planId, required couponCode}) async {
        receiptCalls++;
        return right('ok');
      },
      retryDelays: const [Duration(seconds: 30)], // don't fire during the test
    );

    await ack.acknowledge(
      _purchase(receipt: ''),
      planId: '1y-usd-10',
      couponCode: '',
      onSuccess: (_) => rec.success++,
      onError: (_) => rec.error++,
    );

    expect(receiptCalls, 0); // never hit the backend with an empty receipt
    expect(rec.error, 1);
    expect(rec.acknowledged, 0);
    ack.dispose(); // cancel the pending retry timer
  });

  test('a thrown backend error is retried, not propagated', () async {
    var calls = 0;
    final ack = build(
      acknowledgeReceipt: ({required purchaseToken, required planId, required couponCode}) async {
        calls++;
        if (calls == 1) throw Exception('network down');
        return right('ok');
      },
    );

    // Must not throw out of acknowledge().
    await ack.acknowledge(
      _purchase(),
      planId: '1y-usd-10',
      couponCode: '',
      onSuccess: (_) => rec.success++,
      onError: (_) => rec.error++,
    );

    expect(rec.error, 1); // surfaced once
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(calls, 2); // retried
    expect(rec.acknowledged, 1); // and succeeded
  });

  test('background retries stop after maxRetries when the backend never recovers', () async {
    var calls = 0;
    final ack = build(
      acknowledgeReceipt: ({required purchaseToken, required planId, required couponCode}) async {
        calls++;
        return left(_failure());
      },
      retryDelays: const [Duration(milliseconds: 1)],
      maxRetries: 3,
    );

    await ack.acknowledge(
      _purchase(),
      planId: '1y-usd-10',
      couponCode: '',
      onSuccess: (_) => rec.success++,
      onError: (_) => rec.error++,
    );

    // Give the bounded retry chain time to run to exhaustion.
    await Future<void>.delayed(const Duration(milliseconds: 60));

    // 1 initial attempt + 3 retries, then the cap stops further scheduling.
    expect(calls, 4);
    expect(rec.error, 1); // surfaced once on the first failure
    expect(rec.acknowledged, 0);

    // No more calls happen after exhaustion.
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(calls, 4);
  });

  test('a duplicate in-flight acknowledge for the same purchase is ignored', () async {
    final completer = Completer<Either<Failure, String>>();
    final ack = build(
      acknowledgeReceipt: ({required purchaseToken, required planId, required couponCode}) =>
          completer.future,
    );

    final purchase = _purchase();
    // Start one (does not complete yet), then a second for the same key.
    final first = ack.acknowledge(
      purchase,
      planId: '1y-usd-10',
      couponCode: '',
      onSuccess: (_) => rec.success++,
      onError: (_) => rec.error++,
    );
    await ack.acknowledge(
      purchase,
      planId: '1y-usd-10',
      couponCode: '',
      onSuccess: (_) => rec.success++,
      onError: (_) => rec.error++,
    );

    completer.complete(right('ok'));
    await first;

    expect(rec.success, 1); // only the first attempt ran
    expect(rec.acknowledged, 1);
  });
}
