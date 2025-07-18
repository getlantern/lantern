import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lantern/core/common/app_colors.dart';
import 'package:lantern/core/utils/platform_utils.dart';

class SwitchButton extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? activeColor;

  const SwitchButton({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomAnimatedToggleSwitch<bool>(
      current: value,
      onTap: (_) => onChanged(!value),
      values: [false, true],
      animationDuration: const Duration(milliseconds: 200),
      onChanged: onChanged,
      iconBuilder: (context, local, global) => const SizedBox(),
      indicatorSize: const Size(30, 30),
      spacing: 10.h,
      height: PlatformUtils.isDesktop ? 40.h : 30.h,
      wrapperBuilder: (context, global, child) {
        return Container(
          width: 75,
          padding: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: value ? (activeColor ?? AppColors.green5) : AppColors.gray7,
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
