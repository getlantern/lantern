import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/providers/apps_data_provider.dart';
import 'package:lantern/core/split_tunneling/app_data.dart';
import 'package:lantern/core/split_tunneling/split_tunneling_notifier.dart';
import 'package:lantern/core/widgets/search_bar.dart';
import 'package:lantern/features/split_tunneling/section_label.dart';

// Mock data representing installed apps
final List<AppData> _mockApps = [
  AppData(
      name: "Apple Music",
      bundleId: "com.apple.music",
      appPath: "",
      iconPath: AppImagePaths.appleMusicIcon,
      isEnabled: false),
  AppData(
      name: "Google Chat",
      bundleId: "com.google.chat",
      appPath: "",
      iconPath: AppImagePaths.googleChatIcon,
      isEnabled: true),
  AppData(
      name: "Instagram",
      bundleId: "com.example.instagram",
      appPath: "",
      iconPath: AppImagePaths.instagramIcon,
      isEnabled: true),
];

// Widget to display and manage split tunneling apps
@RoutePage(name: 'AppsSplitTunneling')
class AppsSplitTunneling extends HookConsumerWidget {
  const AppsSplitTunneling({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchEnabled = useState(false);
    final searchQuery = ref.watch(searchQueryProvider);

    final installedApps =
        ref.watch(appsDataProvider).where((a) => a.iconPath.isNotEmpty);
    final enabledApps = ref.watch(splitTunnelingAppsProvider);
    final enabledList = enabledApps.toList();
    enabledList
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    // Separate enabled and disabled apps
    final disabledApps = installedApps
        .where(
            (app) => app.name.toLowerCase().contains(searchQuery.toLowerCase()))
        .where((app) => !enabledApps.any((e) => e.name == app.name))
        .toSet();

    final disabledList = disabledApps.toList();
    disabledList
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    print("enabledApps: $enabledApps");

    return BaseScreen(
      title: 'apps_split_tunneling'.i18n,
      appBar: CustomAppBar(
        title: searchEnabled.value
            ? AppSearchBar(
                hintText: 'search_apps'.i18n,
              )
            : 'apps_split_tunneling'.i18n,
        actionsPadding: EdgeInsets.only(right: 24.0),
        actions: [
          AppIconButton(
            onPressed: () => searchEnabled.value = !searchEnabled.value,
            path: AppImagePaths.search,
          ),
        ],
      ),
      body: CustomScrollView(slivers: [
        if (enabledApps.isNotEmpty) ...[
          SliverToBoxAdapter(
              child: SectionLabel(
                  'apps_bypassing_vpn'.i18n.fill([enabledApps.length]))),
          SliverList.list(
            children: enabledList
                .map((app) => _AppRow(
                      app: app.copyWith(isEnabled: true),
                      onToggle: () => ref
                          .read(splitTunnelingAppsProvider.notifier)
                          .toggleApp(app),
                    ))
                .toList(),
          ),
        ],
        if (disabledList.isNotEmpty) ...[
          SliverToBoxAdapter(child: SectionLabel('installed_apps'.i18n)),
          SliverList.list(
            children: disabledList
                .map((app) => _AppRow(
                      app: app,
                      onToggle: () => ref
                          .read(splitTunnelingAppsProvider.notifier)
                          .toggleApp(app),
                    ))
                .toList(),
          ),
        ],
      ]),
    );
  }
}

// Individual app row component
class _AppRow extends StatelessWidget {
  final AppData app;
  final VoidCallback? onToggle;

  const _AppRow({
    required this.app,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AppTile(
      label: app.name.replaceAll(".app", ""),
      icon: app.iconPath.isNotEmpty
          ? Image.file(File(app.iconPath), width: 24, height: 24)
          : Icon(Icons.apps),
      trailing: onToggle != null
          ? Padding(
              padding: const EdgeInsets.only(right: 16),
              child: IconButton(
                icon: AppImage(
                  color: Colors.black,
                  path:
                      app.isEnabled ? AppImagePaths.minus : AppImagePaths.plus,
                ),
                onPressed: () => onToggle!(),
              ),
            )
          : null,
    );
  }
}
