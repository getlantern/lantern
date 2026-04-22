import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppVersion extends StatelessWidget {
  const AppVersion({super.key});

  @override
  Widget build(BuildContext context) {
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
              _InfoRow(
                label: 'Build',
                value: build,
                textTheme: textTheme,
              ),
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
