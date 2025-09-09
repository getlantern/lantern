import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'system_extension_notifier.g.dart';

@Riverpod()
class SystemExtensionNotifier extends _$SystemExtensionNotifier {
  @override
  SystemExtensionStatus build() {
    isSystemExtensionInstalled();
    return SystemExtensionStatus.unknown;
  }

  Future<Either<Failure, SystemExtensionStatus>> triggerSystemExtensionInstallation() async {
    return ref.read(lanternServiceProvider).triggerSystemExtension();
  }

  Future<void> isSystemExtensionInstalled() async {
    final result =
        await ref.read(lanternServiceProvider).isSystemExtensionInstalled();

    result.fold(
      (failure) {
        state = SystemExtensionStatus.notInstalled;
        appLogger.error("Failure: ${failure.localizedErrorMessage}");
      },
      (result) {
        state = result;
        appLogger.info("System Extension Installed: $result");
      },
    );
  }
}
