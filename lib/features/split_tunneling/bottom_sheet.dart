import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/preferences/app_preferences.dart';
import 'package:lantern/core/split_tunneling/split_tunneling_mode.dart';

class SplitTunnelingBottomSheet extends HookConsumerWidget {
  final SplitTunnelingMode selectedMode;
  final ScrollController? scrollController;
  final Function(SplitTunnelingMode) onModeSelected;

  const SplitTunnelingBottomSheet({
    super.key,
    required this.selectedMode,
    required this.onModeSelected,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(appPreferencesProvider).value;
    final splitTunnelingMode = preferences?[Preferences.splitTunnelingMode] ??
        SplitTunnelingMode.automatic;

    return ListView(
      controller: scrollController,
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      children: [
        // Options
        ...SplitTunnelingMode.values.map((mode) {
          return RadioListTile<SplitTunnelingMode>(
            title: Text(
              mode.displayName,
              style: AppTestStyles.bodyLarge.copyWith(
                color: const Color(0xFF1A1B1C),
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
      ],
    );
  }
}
