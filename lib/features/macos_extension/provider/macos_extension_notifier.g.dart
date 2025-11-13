// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'macos_extension_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MacosExtensionNotifier)
const macosExtensionProvider = MacosExtensionNotifierProvider._();

final class MacosExtensionNotifierProvider
    extends $NotifierProvider<MacosExtensionNotifier, MacOSExtensionState> {
  const MacosExtensionNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'macosExtensionProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$macosExtensionNotifierHash();

  @$internal
  @override
  MacosExtensionNotifier create() => MacosExtensionNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MacOSExtensionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MacOSExtensionState>(value),
    );
  }
}

String _$macosExtensionNotifierHash() =>
    r'842302433894032ee9670f1910f52ffef193b2b4';

abstract class _$MacosExtensionNotifier extends $Notifier<MacOSExtensionState> {
  MacOSExtensionState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<MacOSExtensionState, MacOSExtensionState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<MacOSExtensionState, MacOSExtensionState>,
        MacOSExtensionState,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
