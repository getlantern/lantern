import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/helpers/models/helpers_view.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';
import 'package:lantern/features/vpn/personal_proxies_section.dart';
import 'package:lantern/features/vpn/provider/personal_proxy_status_notifier.dart';

class _Helpers extends HelpersNotifier {
  _Helpers(this.initial);
  final HelpersState initial;
  @override
  HelpersState build() => initial;
  @override
  Future<void> refreshIfUsed() async {}
}

class _Status extends PersonalProxyStatusNotifier {
  _Status(this.initial);
  final Map<String, PersonalProxyStatus>? initial;
  @override
  Map<String, PersonalProxyStatus>? build() => initial;
  @override
  Future<void> poll() async {}
}

HelpersState _with(List<HelperPairingView> helpers) => HelpersState(
  viewLoaded: true,
  view: HelpersView(unlocked: true, helpers: helpers),
);

final _friendTaps = <String>[];

Future<List<int>> _pump(
  WidgetTester tester,
  HelpersState state, {
  bool selected = false,
  Map<String, PersonalProxyStatus>? status,
  String? selectedFriend,
  bool selectFriends = false,
}) async {
  final taps = <int>[];
  _friendTaps.clear();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        helpersProvider.overrideWith(() => _Helpers(state)),
        personalProxyStatusProvider.overrideWith(() => _Status(status)),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        child: MaterialApp(
          theme: AppTheme.appTheme(),
          home: Scaffold(
            body: PersonalProxiesSection(
              selected: selected,
              onSelect: () => taps.add(1),
              selectedFriend: selectedFriend,
              onSelectFriend: selectFriends
                  ? (h) => _friendTaps.add(h.outboundTag)
                  : null,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return taps;
}

void main() {
  const ali = HelperPairingView(pairingId: 'p1', name: 'Ali', online: true);
  const bo = HelperPairingView(pairingId: 'p2', name: 'Bo');

  testWidgets('one selectable row, then each friend for information', (
    tester,
  ) async {
    final taps = await _pump(tester, _with([ali, bo]));
    expect(find.text('personal_proxies'.i18n), findsOneWidget);
    expect(find.text('your_personal_proxies'.i18n), findsOneWidget);
    expect(find.text('Ali'), findsOneWidget);
    expect(find.text('Bo'), findsOneWidget);
    expect(find.text('helper_online'.i18n), findsOneWidget);
    expect(find.text('helper_offline'.i18n), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('server_selection.personal_proxy.p1')),
    );
    expect(taps, isEmpty, reason: 'friend rows are not tappable');
    await tester.tap(
      find.byKey(const Key('server_selection.personal_proxies')),
    );
    expect(taps, hasLength(1));
  });

  testWidgets('an offline friend is veiled like a locked Pro location: no '
      'radio, not tappable', (tester) async {
    await _pump(tester, _with([ali, bo]));
    final veil = find.byKey(
      const Key('server_selection.personal_proxy.offline.p2'),
    );
    expect(veil, findsOneWidget);
    expect(
      find.byKey(const Key('server_selection.personal_proxy.offline.p1')),
      findsNothing,
    );
    final container = tester.widget<Container>(
      find.descendant(of: veil, matching: find.byType(Container)).last,
    );
    final color = (container.decoration! as BoxDecoration).color!;
    expect(color.a, closeTo(0.72, 0.01));
    final tile = tester.widget<ListTile>(
      find.descendant(
        of: find.byKey(const Key('server_selection.personal_proxy.p2')),
        matching: find.byType(ListTile),
        matchRoot: true,
      ),
    );
    expect(tile.onTap, isNull);
  });

  testWidgets('friend rows show no radio and no place until a friend can be '
      'selected on their own', (tester) async {
    expect(ali.selectable(null), isFalse, reason: 'no outbound tag yet');
    await _pump(tester, _with([ali, bo]), selectFriends: true);
    expect(find.byType(AppRadioButton<String>), findsNothing);
    expect(find.byType(Flag), findsNothing);
    final tile = tester.widget<ListTile>(
      find.descendant(
        of: find.byKey(const Key('server_selection.personal_proxy.p1')),
        matching: find.byType(ListTile),
        matchRoot: true,
      ),
    );
    expect(tile.onTap, isNull);
  });

  testWidgets('the row is disabled while no friend is online', (tester) async {
    final taps = await _pump(tester, _with([bo]));
    await tester.tap(
      find.byKey(const Key('server_selection.personal_proxies')),
    );
    expect(taps, isEmpty);
  });

  testWidgets('absent without pairings', (tester) async {
    await _pump(tester, _with(const []));
    expect(find.text('personal_proxies'.i18n), findsNothing);
    expect(
      find.byKey(const Key('server_selection.personal_proxies')),
      findsNothing,
    );
  });

  testWidgets('selecting the selected row does nothing', (tester) async {
    final taps = await _pump(tester, _with([ali]), selected: true);
    await tester.tap(
      find.byKey(const Key('server_selection.personal_proxies')),
    );
    expect(taps, isEmpty);
  });

  group('one friend selected', () {
    const sara = HelperPairingView(
      pairingId: 'p3',
      name: 'Sara',
      online: true,
      outboundTag: 'helper-0123456789ab',
    );
    const live = {'helper-0123456789ab': PersonalProxyStatus(direct: true)};
    Finder saraRow() =>
        find.byKey(const Key('server_selection.personal_proxy.p3'));
    Finder radio() =>
        find.descendant(of: saraRow(), matching: find.byType(Radio<String>));
    Finder radioButton() => find.descendant(
      of: saraRow(),
      matching: find.byType(AppRadioButton<String>),
    );

    testWidgets('a live friend shows a radio that selects them', (
      tester,
    ) async {
      await _pump(tester, _with([sara, bo]), status: live, selectFriends: true);
      expect(radio(), findsOneWidget);
      expect(
        tester.widget<AppRadioButton<String>>(radioButton()).groupValue,
        isNull,
      );
      await tester.tap(radio());
      expect(_friendTaps, ['helper-0123456789ab']);
      await tester.tap(saraRow());
      expect(_friendTaps, hasLength(2), reason: 'the row selects too');
      expect(find.byType(Flag), findsNothing);
    });

    testWidgets('the selected friend shows checked; tapping again does '
        'nothing', (tester) async {
      await _pump(
        tester,
        _with([sara]),
        status: live,
        selectFriends: true,
        selectedFriend: 'helper-0123456789ab',
      );
      expect(
        tester.widget<AppRadioButton<String>>(radioButton()).groupValue,
        'p3',
      );
      await tester.tap(radio());
      await tester.tap(saraRow());
      expect(_friendTaps, isEmpty);
    });

    testWidgets('no radio while radiance has no route to the friend', (
      tester,
    ) async {
      await _pump(tester, _with([sara]), status: const {}, selectFriends: true);
      expect(radio(), findsNothing);
      await tester.tap(saraRow());
      expect(_friendTaps, isEmpty);
    });

    testWidgets('with the VPN off (no status) online alone decides', (
      tester,
    ) async {
      await _pump(tester, _with([sara]), selectFriends: true);
      expect(radio(), findsOneWidget);
    });

    testWidgets('selecting a friend leaves the group row unselected but '
        'selectable', (tester) async {
      final taps = await _pump(
        tester,
        _with([sara]),
        status: live,
        selectFriends: true,
        selectedFriend: 'helper-0123456789ab',
      );
      await tester.tap(
        find.byKey(const Key('server_selection.personal_proxies')),
      );
      expect(taps, hasLength(1));
    });
  });
}
