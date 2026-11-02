import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/utils/helper_tags.dart';
import 'package:lantern/core/widgets/app_text.dart';
import 'package:lantern/features/helpers/models/helpers_view.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';
import 'package:lantern/features/vpn/provider/personal_proxy_status_notifier.dart';

/// The Private Locations tab's "Personal Proxies": one selectable row that
/// connects through every friend at once, then each friend by name with
/// Online or Offline, and never where they are. An offline friend looks like
/// a locked Pro location: greyed out, no radio, not tappable. A friend's row
/// has a radio and selects that friend alone while
/// [HelperPairingView.selectable] says so; until then it is for information.
/// Nothing shows without a pairing; the group row is disabled while no
/// friend is online.
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

  /// The outbound tag of the friend selected on their own, if any.
  final String? selectedFriend;
  final ValueChanged<HelperPairingView>? onSelectFriend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final helpers = ref.watch(helpersProvider.select((s) => s.view.helpers));
    if (helpers.isEmpty) return const SizedBox.shrink();
    final status = ref.watch(personalProxyStatusProvider);
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
                  selectable: h.selectable(status),
                  selected:
                      h.outboundTag.isNotEmpty &&
                      selectedFriend == h.outboundTag,
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
    required this.selectable,
    required this.selected,
    required this.onSelect,
  });

  final HelperPairingView helper;
  final bool selectable;
  final bool selected;
  final ValueChanged<HelperPairingView>? onSelect;

  @override
  Widget build(BuildContext context) {
    final select = onSelect;
    final selectable = this.selectable && select != null;
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
      // The selected friend keeps its checked radio while radiance falls
      // back, so the list never shows nothing selected.
      trailing: selectable || selected
          ? AppRadioButton<String>(
              value: helper.pairingId,
              groupValue: selected ? helper.pairingId : null,
              onChanged: selectable
                  ? (_) {
                      if (!selected) select(helper);
                    }
                  : null,
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

/// What the app calls the friend whose outbound tag is [tag]: their name in
/// [view], or the generic helper name when the view does not know them or
/// they have none. Never where they are.
String personalProxyFriendLabel(HelpersView view, String tag) {
  final name = view.helperByTag(tag)?.name ?? '';
  return name.isEmpty ? 'helper_unnamed'.i18n : name;
}

/// [personalProxyFriendLabel] for a widget, rebuilt when the name changes.
String personalProxyFriendName(WidgetRef ref, String tag) => ref.watch(
  helpersProvider.select((s) => personalProxyFriendLabel(s.view, tag)),
);

/// The message for radiance switching the selected friend whose outbound tag
/// is [tag], who has no route left, to [fallback]: the personal proxies group
/// or Smart Location. Null for a fallback radiance does not send.
String? personalProxyFallbackMessage(
  HelpersView view,
  String tag,
  String fallback,
) {
  final key = switch (fallback) {
    personalProxiesTag => 'personal_proxy_fallback_group',
    'auto' => 'personal_proxy_fallback_auto',
    _ => null,
  };
  if (key == null) return null;
  return key.i18n.fill([personalProxyFriendLabel(view, tag)]);
}
