// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Notifier to manage the state of payment sessions

@ProviderFor(PaymentSessionNotifier)
final paymentSessionProvider = PaymentSessionNotifierProvider._();

/// Notifier to manage the state of payment sessions
final class PaymentSessionNotifierProvider
    extends $NotifierProvider<PaymentSessionNotifier, bool> {
  /// Notifier to manage the state of payment sessions
  PaymentSessionNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'paymentSessionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$paymentSessionNotifierHash();

  @$internal
  @override
  PaymentSessionNotifier create() => PaymentSessionNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$paymentSessionNotifierHash() =>
    r'c15fd9b434720884b8b9252b06ed22cb5f34d3a8';

/// Notifier to manage the state of payment sessions

abstract class _$PaymentSessionNotifier extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(PaymentNotifier)
final paymentProvider = PaymentNotifierProvider._();

final class PaymentNotifierProvider
    extends $NotifierProvider<PaymentNotifier, void> {
  PaymentNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'paymentProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$paymentNotifierHash();

  @$internal
  @override
  PaymentNotifier create() => PaymentNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$paymentNotifierHash() => r'593bf59110bb4eb70a843d440467573d9b5bb5cd';

abstract class _$PaymentNotifier extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
