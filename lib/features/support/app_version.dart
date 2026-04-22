import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_build_info.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/developer/notifier/developer_mode_notifier.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Number of taps on the build row required to toggle developer mode.
const int _devModeTapThreshold = 5;

/// Window in which consecutive taps count toward toggling dev mode.
const Duration _devModeTapWindow = Duration(seconds: 3);

/// Whether the current build permits enabling developer mode. Nightly and
/// debug builds only — release/production builds never surface the toggle.
bool get _canEnableDevMode =>
    kDebugMode || AppBuildInfo.buildType == 'nightly';

class AppVersion extends HookConsumerWidget {
  const AppVersion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;

    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snap) {
        final version = snap.data?.version ?? '…';
        final build = snap.data?.buildNumber ?? '…';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: context.bgSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border(
              top: BorderSide(color: context.borderDefault, width: 1),
              bottom: BorderSide(color: context.borderDefault, width: 1),
            ),
          ),
          child: Column(
            children: [
              _InfoRow(
                label: 'lantern_version'.i18n,
                value: version,
                textTheme: textTheme,
              ),
              Divider(height: 1, color: context.borderDefault),
              _BuildRow(value: build, textTheme: textTheme),
            ],
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.textTheme,
  });

  final String label;
  final String value;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: textTheme.bodyMedium),
          Text(
            value,
            style: textTheme.titleSmall!.copyWith(color: context.textLink),
          ),
        ],
      ),
    );
  }
}

/// Hidden dev-mode toggle: tapping the Build row [_devModeTapThreshold] times
/// in quick succession flips the persisted developer-mode flag.
class _BuildRow extends HookConsumerWidget {
  const _BuildRow({required this.value, required this.textTheme});

  final String value;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tapCount = useState(0);
    final firstTapAt = useState<DateTime?>(null);

    Future<void> onTap() async {
      final wasEnabled = ref.read(developerModeProvider).enabled;
      // Only nightly/debug builds can *enable* dev mode; already-enabled state
      // can still be turned off anywhere so users aren't stuck with it on.
      if (!wasEnabled && !_canEnableDevMode) return;

      final now = DateTime.now();
      final first = firstTapAt.value;
      if (first == null || now.difference(first) > _devModeTapWindow) {
        tapCount.value = 1;
        firstTapAt.value = now;
        return;
      }
      final next = tapCount.value + 1;
      tapCount.value = next;
      if (next < _devModeTapThreshold) return;

      tapCount.value = 0;
      firstTapAt.value = null;
      final notifier = ref.read(developerModeProvider.notifier);
      await notifier.setEnabled(!wasEnabled);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasEnabled ? 'Developer mode disabled' : 'Developer mode enabled',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Build', style: textTheme.bodyMedium),
            Text(
              value,
              style: textTheme.titleSmall!.copyWith(color: context.textLink),
            ),
          ],
        ),
      ),
    );
  }
}
