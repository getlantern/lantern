import 'package:lantern/core/utils/platform_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/common/common.dart';

part 'system_tray_notifier.g.dart';

@Riverpod(keepAlive: true)
class SystemTrayNotifier extends _$SystemTrayNotifier {
  @override
  Future<void> build() async {
    if (!PlatformUtils.isDesktop) return;
  }
}
