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
    const trackWidth = 70.0;

    return CustomAnimatedToggleSwitch<bool>(
      current: value,
      values: const [false, true],
      animationDuration: const Duration(milliseconds: 200),
      onChanged: onChanged,
      iconBuilder: (context, local, global) => const SizedBox(),
      indicatorSize: const Size(30, 30),
      spacing: 10.h,
      height: PlatformUtils.isDesktop ? 40.h : 30.h,
      wrapperBuilder: (context, global, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          width: trackWidth,
          padding: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            // toggle-active-bg: Green.500 light / Green.700 dark
            // toggle-disabled-bg (off state): Gray.700 both
            color: value
                ? (activeColor ??
                    (isDark ? AppColors.green7 : AppColors.green5))
                : AppColors.gray7,
            borderRadius: BorderRadius.circular(100),
          ),
          child: child,
        );
      },
      foregroundIndicatorBuilder: (context, global) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return GestureDetector(
          onTap: () {
            onChanged(value ? false : true);
          },
          child: Container(
            decoration: BoxDecoration(
              // toggle-knob-bg: White light / Gray.100 dark
              color: isDark ? AppColors.gray1 : Colors.white,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
