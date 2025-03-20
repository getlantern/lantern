import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/preferences/preferences.dart';
import 'package:lantern/core/split_tunneling/split_tunneling_mode.dart';

class SplitTunnelingBottomSheet extends HookConsumerWidget {
  final SplitTunnelingMode selectedMode;
  final Function(SplitTunnelingMode) onModeSelected;

  const SplitTunnelingBottomSheet({
    super.key,
    required this.selectedMode,
    required this.onModeSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(appPreferencesProvider);
    final splitTunnelingMode = preferences[AppPreferences.splitTunnelingMode] ??
        SplitTunnelingMode.automatic;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Text(
            'split_tunneling_mode'.i18n,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF012D2D),
              fontSize: 24,
              fontFamily: 'Urbanist',
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
          const SizedBox(height: 16),

          // Options
          Column(
            children: SplitTunnelingMode.values.map((mode) {
              return RadioListTile<SplitTunnelingMode>(
                title: Text(
                  mode.displayName,
                  style: TextStyle(
                    color: Color(0xFF1A1B1C),
                    fontSize: 16,
                    fontFamily: 'Urbanist',
                    fontWeight: FontWeight.w400,
                  ),
                ),
                value: mode,
                activeColor: AppColors.gray9,
                selected: splitTunnelingMode == mode,
                groupValue: selectedMode,
                onChanged: (SplitTunnelingMode? newValue) {
                  if (newValue != null) {
                    onModeSelected(newValue);
                    Navigator.pop(context); // Close modal on selection
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
