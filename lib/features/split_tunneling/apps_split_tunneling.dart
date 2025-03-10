import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/split_tunneling/app_data.dart';
import 'package:lantern/core/split_tunneling/split_tunneling_notifier.dart';
import 'package:lantern/core/widgets/search_bar.dart';
import 'package:lantern/features/split_tunneling/section_label.dart';

// Mock data representing installed apps
final List<AppData> _mockApps = [
  AppData(
      name: "Apple Music",
      package: "com.apple.music",
      iconPath: AppImagePaths.appleMusicIcon,
      isEnabled: false),
  AppData(
      name: "Google Chat",
      package: "com.google.chat",
      iconPath: AppImagePaths.googleChatIcon,
      isEnabled: true),
  AppData(
      name: "Instagram",
      package: "com.example.instagram",
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

    // Separate enabled and disabled apps
    final enabledApps = ref.watch(splitTunnelingAppsProvider);
    final disabledApps = _mockApps
        .where(
            (app) => app.name.toLowerCase().contains(searchQuery.toLowerCase()))
        .where((app) => !enabledApps.any((e) => e.package == app.package))
        .toList();
    final installedApps = disabledApps.map((app) {
      final isEnabled =
          enabledApps.any((enabledApp) => enabledApp.package == app.package);
      return app.copyWith(isEnabled: isEnabled);
    }).toList();
    return BaseScreen(
      title: 'apps_split_tunneling'.i18n,
      appBar: CustomAppBar(
        title:
            searchEnabled.value ? AppSearchBar() : 'apps_split_tunneling'.i18n,
        actionsPadding: EdgeInsets.only(right: 24.0),
        actions: [
          AppIconButton(
            onPressed: () => searchEnabled.value = !searchEnabled.value,
            path: AppImagePaths.search,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(height: defaultSize),
          // Enabled Apps Section
          if (enabledApps.isNotEmpty) ...[
            SectionLabel(
              'apps_bypassing_vpn'.i18n.fill([enabledApps.length]),
            ),
            ...enabledApps.map((app) => _AppRow(
                  app: app,
                  onToggle: () => ref
                      .read(splitTunnelingAppsProvider.notifier)
                      .toggleApp(app),
                )),
            SizedBox(height: defaultSize),
          ],
          SectionLabel('installed_apps'.i18n),
          ...installedApps.map(
            (app) => _AppRow(
              app: app,
              onToggle: () =>
                  ref.read(splitTunnelingAppsProvider.notifier).toggleApp(app),
            ),
          ),
          SizedBox(height: defaultSize),
        ],
      ),
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
      label: app.name,
      icon: app.iconPath,
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
