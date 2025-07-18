import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/features/system_tray/provider/system_tray_notifier.dart';

class SystemTrayWrapper extends ConsumerWidget {
  final Widget child;

  const SystemTrayWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(systemTrayNotifierProvider);
    return child;
  }
}
