import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:flutter/material.dart';

class SwitchButton extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const SwitchButton({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CustomAnimatedToggleSwitch<bool>(
      current: value,
      values: [false, true],
      animationDuration: const Duration(milliseconds: 200),
      onChanged: onChanged,
      iconBuilder: (context, local, global) => const SizedBox(),
      indicatorSize: const Size(30, 30),
      spacing: 0.0,
      height: 40,
      wrapperBuilder: (context, global, child) {
        return Container(
          width: 75,
          padding: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: value ? const Color(0xFF1FBF63) : const Color(0xFF616569),
            borderRadius: BorderRadius.circular(100),
          ),
          child: child,
        );
      },
      foregroundIndicatorBuilder: (context, global) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
        );
      },
    );
  }
}
