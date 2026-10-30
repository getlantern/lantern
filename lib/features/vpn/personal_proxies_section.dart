import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/app_text.dart';
import 'package:lantern/features/helpers/models/helpers_view.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';

/// The Private Locations tab's "Personal proxies": one selectable row that
/// connects through every friend at once, then each friend by name with an
/// online or offline label, for information only. Nothing shows without a
/// pairing; the row is disabled while no friend is online.
class PersonalProxiesSection extends ConsumerWidget {
  const PersonalProxiesSection({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final helpers = ref.watch(helpersProvider.select((s) => s.view.helpers));
    if (helpers.isEmpty) return const SizedBox.shrink();
    final anyOnline = helpers.any((h) => h.online);
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: HeaderText('personal_proxies'.i18n),
        ),
        const SizedBox(height: 8),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTile(
                tileKey: const Key('server_selection.personal_proxies'),
                icon: AppImagePaths.location,
                label: 'your_personal_proxies'.i18n,
                enabled: anyOnline,
                onPressed: anyOnline && !selected ? onSelect : null,
                trailing: selected ? AppImage(path: AppImagePaths.blot) : null,
              ),
              for (final h in helpers) ...[
                const DividerSpace(),
                _FriendRow(helper: h, textTheme: textTheme),
              ],
            ],
          ),
        ),
        const SizedBox(height: defaultSize),
      ],
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({required this.helper, required this.textTheme});

  final HelperPairingView helper;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) => AppTile(
    tileKey: Key('server_selection.personal_proxy.${helper.pairingId}'),
    label: helper.name.isEmpty ? 'helper_unnamed'.i18n : helper.name,
    subtitle: Row(
      children: [
        Icon(
          Icons.circle,
          size: 10,
          color: helper.online
              ? context.statusSuccessBgDot
              : context.textTertiary,
        ),
        const SizedBox(width: 6),
        Text(
          helper.online ? 'helper_online'.i18n : 'helper_offline'.i18n,
          style: textTheme.labelMedium!.copyWith(color: context.textTertiary),
        ),
      ],
    ),
  );
}
