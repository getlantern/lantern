import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SystemTrayWrapper extends StatefulHookConsumerWidget {
  final Widget child;

  const SystemTrayWrapper({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<SystemTrayWrapper> createState() => _SystemTrayWrapperState();
}

class _SystemTrayWrapperState extends ConsumerState<SystemTrayWrapper> {
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
