import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'local_storage_notifier.g.dart';

@Riverpod(keepAlive: true)
class LocalStorageNotifier extends _$LocalStorageNotifier {
  @override
  LocalStorageService build() {
    return sl<LocalStorageService>();
  }
}
