import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lantern/core/common/common.dart'
    hide InviteShare, ServerSelection;
import 'package:lantern/core/models/app_setting.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/core/models/share_state.dart';
import 'package:lantern/features/action_mode/action_mode.dart';
import 'package:lantern/features/action_mode/action_mode_welcome_dialog.dart';
import 'package:lantern/features/action_mode/provider/share_notifier.dart';
import 'package:lantern/features/helpers/approve_helper_dialog.dart';
import 'package:lantern/features/helpers/helping_friends.dart';
import 'package:lantern/features/helpers/invite_share.dart';
import 'package:lantern/features/helpers/models/helpers_view.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/home/provider/country_code_notifier.dart';
import 'package:lantern/features/vpn/provider/available_servers_notifier.dart';
import 'package:lantern/features/vpn/provider/personal_proxy_status_notifier.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/server_selection.dart';

// Renders the Personal Proxies and Action Mode screens to PNGs to compare
// with the design. Runs only with --dart-define=PP_SHOTS=<dir> and
// PP_FONTS=<a directory holding Urbanist-*.ttf> and PP_ICONS=<the path of
// MaterialIcons-Regular.otf>.
const _shotsDir = String.fromEnvironment('PP_SHOTS');
const _fontsDir = String.fromEnvironment('PP_FONTS');
const _iconsFont = String.fromEnvironment('PP_ICONS');
const _size = Size(393, 852);
final _boundary = GlobalKey();

class _Helpers extends HelpersNotifier {
  _Helpers(this.initial);
  final HelpersState initial;
  @override
  HelpersState build() => initial;
  @override
  Future<void> refreshIfUsed() async {}
  @override
  Future<void> loadHelpOthers() async {}
  @override
  Future<HelperResult> refresh() async => HelperResult.parse('{}');
  @override
  Future<HelperResult> decide(String inviteId, {required bool approve}) async {
    state = const HelpersState(
      viewLoaded: true,
      view: HelpersView(unlocked: true, helpers: [_sara]),
    );
    return HelperResult.parse('{}');
  }
}

class _Share extends ShareNotifier {
  _Share(this.initial);
  final ShareState initial;
  @override
  ShareState build() => initial;
  @override
  void replayCurrentPeers() {}
}

class _Settings extends AppSettingNotifier {
  @override
  AppSetting build() =>
      AppSetting(unboundedWelcomeSeen: true, unboundedSessionCount: 2);
  @override
  void setUnboundedWelcomeSeen(bool value) {}
}

class _Servers extends AvailableServersNotifier {
  @override
  Future<AvailableServers> build() async => AvailableServers([]);
  @override
  Future<void> refreshAvailableServersAfterProbeSettle() async {}
}

class _Status extends PersonalProxyStatusNotifier {
  @override
  Map<String, PersonalProxyStatus>? build() => null;
  @override
  Future<void> poll() async {}
}

const _sara = HelperPairingView(
  pairingId: 'p1',
  name: 'Sara',
  online: true,
  outboundTag: 'helper-0123456789ab',
  sinceUnix: 1761800000,
  connected: true,
);
const _daniel = HelperPairingView(
  pairingId: 'p2',
  name: 'Daniel',
  outboundTag: 'helper-ba9876543210',
  sinceUnix: 1760800000,
  connected: false,
);
const _invite = HelperInviteView(
  id: 'i1',
  state: 'pending',
  link: 'https://lantern.io/help/#rFfuub6gH1ei',
  inviterName: 'Ali',
);
const _claimed = HelperInviteView(
  id: 'i1',
  state: 'claimed',
  code: '1724',
  volunteerName: 'Sara',
);

Future<void> _loadFonts(WidgetTester tester) async {
  await tester.runAsync(() async {
    Future<void> load(String family, Iterable<File> files) async {
      final loader = FontLoader(family);
      for (final f in files) {
        loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
      }
      await loader.load();
    }

    File font(String weight) => File('$_fontsDir/Urbanist-$weight.ttf');
    await load('Urbanist', [
      for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) font(w),
    ]);
    // The names google_fonts gives each weight of AppTextStyles.
    for (final (family, weight) in [
      ('Urbanist_regular', 'Regular'),
      ('Urbanist_500', 'Medium'),
      ('Urbanist_600', 'SemiBold'),
      ('Urbanist_700', 'Bold'),
    ]) {
      await load(family, [font(weight)]);
    }
    await load('MaterialIcons', [File(_iconsFont)]);
  });
}

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  HelpersState helpers = const HelpersState(),
  ShareState share = const ShareState(
    active: true,
    mode: ShareMode.unbounded,
    unboundedRunning: true,
    activeCount: 5,
    totalCount: 11238,
  ),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = _size;
  addTearDown(tester.view.reset);
  final base = AppTheme.appTheme();
  await http.runWithClient(
    () => tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingProvider.overrideWith(_Settings.new),
          shareProvider.overrideWith(() => _Share(share)),
          helpersProvider.overrideWith(() => _Helpers(helpers)),
          helperInvitesAvailableProvider.overrideWithValue(true),
          countryCodeProvider.overrideWithValue('US'),
          availableServersProvider.overrideWith(_Servers.new),
          personalProxyStatusProvider.overrideWith(_Status.new),
          serverLocationProvider.overrideWithValue(
            ServerLocation(
              serverName: '',
              serverType: ServerLocationType.auto.name,
            ),
          ),
          isUserProProvider.overrideWithValue(false),
        ],
        child: ScreenUtilInit(
          designSize: _size,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: base.copyWith(
              textTheme: base.textTheme.apply(fontFamily: 'Urbanist'),
            ),
            builder: (context, child) =>
                RepaintBoundary(key: _boundary, child: child),
            home: home,
          ),
        ),
      ),
    ),
    () => MockClient(
      (_) async => http.Response(
        jsonEncode({
          'Location': {'Latitude': 37.77, 'Longitude': -122.41},
        }),
        200,
      ),
    ),
  );
  await _settle(tester);
}

/// Lets SVGs and images decode; pumpAndSettle would never return over the
/// turning globe.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<void> _save(WidgetTester tester, String name) async {
  await _settle(tester);
  final boundary =
      tester.renderObject(find.byKey(_boundary)) as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_shotsDir).createSync(recursive: true);
    File('$_shotsDir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

/// A page with a button that runs [open] with a context and ref.
Widget _opener(void Function(BuildContext, WidgetRef) open) => Scaffold(
  body: Consumer(
    builder: (context, ref, _) => Center(
      child: TextButton(
        onPressed: () => open(context, ref),
        child: const Text('open'),
      ),
    ),
  ),
);

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await _settle(tester);
}

void main() {
  setUpAll(Localization.loadTranslations);
  final skip = _shotsDir.isEmpty;

  testWidgets('action_mode_tab', skip: skip, (tester) async {
    HelpersNotifier.debugBuildEnabled = true;
    addTearDown(() => HelpersNotifier.debugBuildEnabled = null);
    await _loadFonts(tester);
    await _pump(
      tester,
      Scaffold(
        appBar: AppBar(
          title: Text('unbounded'.i18n),
          backgroundColor: Colors.white,
          leading: const IconButton(
            onPressed: null,
            icon: AppImage(path: AppImagePaths.accountCircle),
          ),
        ),
        body: const ActionModeTab(),
      ),
      helpers: const HelpersState(
        viewLoaded: true,
        view: HelpersView(unlocked: true, helping: [_sara, _daniel]),
      ),
    );
    await _save(tester, 'action_mode_tab');
  });

  testWidgets('invite_screen', skip: skip, (tester) async {
    await _loadFonts(tester);
    await _pump(
      tester,
      const InviteShare(inviteId: 'i1'),
      helpers: const HelpersState(
        viewLoaded: true,
        view: HelpersView(unlocked: true, myName: 'Ali', invites: [_invite]),
      ),
    );
    await _save(tester, 'invite_screen');
    await tester.tap(find.byKey(const Key('invite.show_qr')));
    await _save(tester, 'qr_dialog');
  });

  testWidgets('approval_dialog', skip: skip, (tester) async {
    await _loadFonts(tester);
    await _pump(
      tester,
      _opener((c, r) => showApproveHelperDialog(c, r, _claimed)),
    );
    await _open(tester);
    await _save(tester, 'approval_dialog');
  });

  testWidgets('success_dialog', skip: skip, (tester) async {
    await _loadFonts(tester);
    await _pump(
      tester,
      _opener((c, r) => showApproveHelperDialog(c, r, _claimed)),
      helpers: const HelpersState(
        viewLoaded: true,
        view: HelpersView(unlocked: true, invites: [_claimed]),
      ),
    );
    await _open(tester);
    // The fake decides at once, as a working engine would.
    await tester.tap(find.text('approve_codes_match'.i18n));
    await _save(tester, 'success_dialog');
  });

  testWidgets('server_list_invite_row', skip: skip, (tester) async {
    await _loadFonts(tester);
    await _pump(
      tester,
      const ServerSelection(),
      helpers: const HelpersState(
        viewLoaded: true,
        view: HelpersView(unlocked: true),
      ),
    );
    await _save(tester, 'server_list_invite_row');
  });

  testWidgets('private_locations', skip: skip, (tester) async {
    await _loadFonts(tester);
    await _pump(
      tester,
      const ServerSelection(),
      helpers: const HelpersState(
        viewLoaded: true,
        view: HelpersView(unlocked: true, helpers: [_sara, _daniel]),
      ),
    );
    await tester.tap(
      find.byKey(const Key('server_selection.private_servers_tab')),
    );
    await _save(tester, 'private_locations');
  });

  testWidgets('friends_sheet', skip: skip, (tester) async {
    await _loadFonts(tester);
    await _pump(
      tester,
      _opener((c, _) => showHelpingFriendsSheet(c)),
      helpers: const HelpersState(
        viewLoaded: true,
        view: HelpersView(
          unlocked: true,
          helping: [_sara, _daniel],
          activity: HelperActivity(
            day: '2026-11-07',
            activeSeconds: 3 * 3600 + 20 * 60,
            relayedBytes: 1200000000,
          ),
        ),
      ),
    );
    await _open(tester);
    await _save(tester, 'friends_sheet');
    await tester.tap(find.byKey(const Key('helping.scope.change')));
    await _save(tester, 'who_youre_helping_sheet');
  });

  testWidgets('welcome_dialog', skip: skip, (tester) async {
    await _loadFonts(tester);
    await _pump(tester, _opener(showActionModeWelcomeDialog));
    await _open(tester);
    await _save(tester, 'welcome_dialog');
  });
}
