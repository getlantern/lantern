import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/app_text.dart';
import 'package:lantern/features/helpers/models/helpers_view.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';

/// The Private Locations tab's "Personal Proxies": one selectable row that
/// connects through every friend at once, then each friend by name with
/// Online or Offline, and never where they are. An offline friend looks like
/// a locked Pro location: greyed out, no radio, not tappable. A friend's row
/// is selectable only once [HelperPairingView.selectable] says so; until
/// then it is for information. Nothing shows without a pairing; the group
/// row is disabled while no friend is online.
class PersonalProxiesSection extends ConsumerWidget {
  const PersonalProxiesSection({
    super.key,
    required this.selected,
    required this.onSelect,
    this.selectedFriend,
    this.onSelectFriend,
  });

  final bool selected;
  final VoidCallback onSelect;

  /// The pairing selected on its own, if any.
  final String? selectedFriend;
  final ValueChanged<HelperPairingView>? onSelectFriend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final helpers = ref.watch(helpersProvider.select((s) => s.view.helpers));
    if (helpers.isEmpty) return const SizedBox.shrink();
    final anyOnline = helpers.any((h) => h.online);
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
                _FriendRow(
                  helper: h,
                  selected: selectedFriend == h.pairingId,
                  onSelect: onSelectFriend,
                ),
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
  const _FriendRow({
    required this.helper,
    required this.selected,
    required this.onSelect,
  });

  final HelperPairingView helper;
  final bool selected;
  final ValueChanged<HelperPairingView>? onSelect;

  @override
  Widget build(BuildContext context) {
    final select = onSelect;
    final selectable = helper.online && helper.selectable && select != null;
    final row = AppTile(
      tileKey: Key('server_selection.personal_proxy.${helper.pairingId}'),
      icon: AppImagePaths.person,
      label: helper.name.isEmpty ? 'helper_unnamed'.i18n : helper.name,
      subtitle: Text(
        helper.online ? 'helper_online'.i18n : 'helper_offline'.i18n,
        style: Theme.of(
          context,
        ).textTheme.labelMedium!.copyWith(color: context.textTertiary),
      ),
      trailing: selectable
          ? AppRadioButton<String>(
              value: helper.pairingId,
              groupValue: selected ? helper.pairingId : null,
              onChanged: (_) => select(helper),
            )
          : null,
      onPressed: selectable && !selected ? () => select(helper) : null,
    );
    if (helper.online) return row;
    // The same veil as the Pro locations a free user cannot pick.
    return Stack(
      key: Key('server_selection.personal_proxy.offline.${helper.pairingId}'),
      children: [
        row,
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                color: context.bgElevated.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
