// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_setting_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AppSettingNotifier)
final appSettingProvider = AppSettingNotifierProvider._();

final class AppSettingNotifierProvider
    extends $NotifierProvider<AppSettingNotifier, AppSetting> {
  AppSettingNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appSettingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appSettingNotifierHash();

  @$internal
  @override
  AppSettingNotifier create() => AppSettingNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppSetting value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppSetting>(value),
    );
  }
}

String _$appSettingNotifierHash() =>
    r'7fac5c306c9e60a16a5962a8d878a4c5e31d46d3';

abstract class _$AppSettingNotifier extends $Notifier<AppSetting> {
  AppSetting build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AppSetting, AppSetting>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppSetting, AppSetting>,
              AppSetting,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
