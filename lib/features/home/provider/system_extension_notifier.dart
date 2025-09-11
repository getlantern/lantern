import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'system_extension_notifier.g.dart';

@Riverpod(keepAlive: true)
class SystemExtensionNotifier extends _$SystemExtensionNotifier {
  @override
  SystemExtensionStatus build() {
    return SystemExtensionStatus.unknown;
  }

  void watchSystemExtensionStatus() {
    ref
        .read(lanternServiceProvider)
        .watchSystemExtensionStatus()
        .listen((status) {
      state = status;
      appLogger.info("System Extension Status Updated: $status");
    });
  }

  Future<Either<Failure, SystemExtensionStatus>>
      triggerSystemExtensionInstallation() async {
    final result =
        await ref.read(lanternServiceProvider).triggerSystemExtension();
    result.fold(
      (failure) {
        appLogger.error("Failure: ${failure.localizedErrorMessage}");
      },
      (status) {
        appLogger.info("System Extension Status: $status");
      },
    );
    return result;
  }

  Future<Either<Failure, Unit>> openSystemExtension() async {
    return ref.read(lanternServiceProvider).openSystemExtension();
  }
}
