import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/models/macos_extension_state.dart';
import 'package:lantern/core/services/logger_service.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'macos_extension_notifier.g.dart';

@Riverpod(keepAlive: true)
class MacosExtensionNotifier extends _$MacosExtensionNotifier {
  StreamSubscription? _extensionStatusSub;

  @override
  MacOSExtensionState build() {
    isSystemExtensionInstalled();
    watchExtensionStatus();
    ref.onDispose(() {
      appLogger.debug(
          'Disposing MacosExtensionNotifier and cancelling subscriptions.');
      _extensionStatusSub?.cancel();
    });
    return MacOSExtensionState(SystemExtensionStatus.notInstalled);
  }

  void watchExtensionStatus() {
    _extensionStatusSub = ref
        .read(lanternServiceProvider)
        .watchSystemExtensionStatus()
        .listen((event) {
      appLogger.info("System Extension Status Updated: ${event.status}");
      state = event;
    });
  }

  Future<Either<Failure, String>> triggerSystemExtensionInstallation() {
    return ref.read(lanternServiceProvider).triggerSystemExtension();
  }

  Future<Either<Failure, Unit>> openSystemExtension() {
    return ref.read(lanternServiceProvider).openSystemExtension();
  }

  Future<Either<Failure, Unit>> isSystemExtensionInstalled() {
    return ref.read(lanternServiceProvider).isSystemExtensionInstalled();
  }
}
