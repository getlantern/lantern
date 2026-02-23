import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';

@RoutePage(name: 'Appearance')
class Appearance extends StatelessWidget {
  const Appearance({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'appearance'.i18n,
      body: Card(
        child: AppearanceListView(),
      ),
    );
  }
}

class AppearanceListView extends ConsumerWidget {
  final ScrollController? scrollController;

  const AppearanceListView({super.key, this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var currentMode = ref.watch(appSettingProvider).themeMode;
    if (currentMode.isEmpty) {
      currentMode = 'system';
    }
    final options = [
      ('system', 'system'.i18n, AppImagePaths.automatic),
      ('light', 'light'.i18n, AppImagePaths.lightMode),
      ('dark', 'dark'.i18n, AppImagePaths.darkMode),
    ];

    return ListView.separated(
      controller: scrollController,
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      itemCount: options.length,
      separatorBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: DividerSpace(),
      ),
      itemBuilder: (context, index) {
        final (value, label, icon) = options[index];
        return AppTile(
          icon: icon,
          label: label,
          minHeight: 56,
          trailing: AppRadioButton<String>(
            value: value,
            groupValue: currentMode,
            onChanged: (selected) => _onSelect(selected!, ref, context),
          ),
          onPressed: () => _onSelect(value, ref, context),
        );
      },
    );
  }

  void _onSelect(String mode, WidgetRef ref, BuildContext context) {
    ref.read(appSettingProvider.notifier).setThemeMode(mode);
    if (!PlatformUtils.isDesktop) {
      appRouter.maybePop();
    }
  }
}

void showAppearanceBottomSheet({required BuildContext context}) {
  showAppBottomSheet(
    context: context,
    title: 'appearance'.i18n,
    scrollControlDisabledMaxHeightRatio: 0.32.h,
    builder: (context, scrollController) {
      return Flexible(
        child: AppearanceListView(scrollController: scrollController),
      );
    },
  );
}

String appearanceModeLabel(String mode) {
  switch (mode) {
    case 'light':
      return 'light'.i18n;
    case 'dark':
      return 'dark'.i18n;
    default:
      return 'system'.i18n;
  }
}
