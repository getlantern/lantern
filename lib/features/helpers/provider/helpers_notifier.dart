import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:lantern/core/common/app_build_info.dart';
import 'package:lantern/core/models/feature_flags.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/core/services/logger_service.dart';
import 'package:lantern/features/helpers/helper_key_store.dart';
import 'package:lantern/features/helpers/models/helpers_view.dart';
import 'package:lantern/features/home/provider/feature_flag_notifier.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'helpers_notifier.g.dart';

/// Whether this build and the server let this device use helper invites.
@riverpod
bool helperInvitesAvailable(Ref ref) =>
    AppBuildInfo.enableHelperInvites &&
    ref.watch(featureFlagProvider).getBool(FeatureFlag.helperInvites);

/// Whether settings offer "Get help from a friend": while helper invites are
/// available, and after the flag goes off while this device still has
/// helpers or invites to manage. Reads only the notifier's state, which stays
/// empty, without the keystore, on a device that never used them.
@riverpod
bool helperEntryVisible(Ref ref) {
  if (!HelpersNotifier._buildEnabled) return false;
  if (ref.watch(helperInvitesAvailableProvider)) return true;
  final view = ref.watch(helpersProvider).view;
  return view.helpers.isNotEmpty || view.invites.any((i) => !i.expired);
}

/// One engine call's result: its JSON, or an error code.
class HelperResult {
  const HelperResult._(this.data, this.error);

  final Map<String, dynamic> data;
  final String? error;

  bool get ok => error == null;

  factory HelperResult.failure(String code) => HelperResult._(const {}, code);

  factory HelperResult.parse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final err = decoded['error'];
        if (err != null) {
          final code = err.toString();
          return HelperResult._(
            const {},
            code == 'not_initialized' ? 'unavailable' : code,
          );
        }
        return HelperResult._(decoded, null);
      }
    } catch (_) {
      // Not JSON: the core is not answering.
    }
    return const HelperResult._({}, 'unavailable');
  }
}

class HelpersState {
  const HelpersState({
    this.view = const HelpersView(),
    this.error,
    this.helpOthers = true,
    this.helpingApprovals = 0,
    this.keystoreReset = false,
  });

  final HelpersView view;

  /// The last operation's error code, cleared by the next success.
  final String? error;

  /// "Help others too" (radiance peer_serve_pool; unset means on).
  final bool helpOthers;

  /// Counts refreshes that found a new pairing this device helps. Home starts
  /// sharing when it grows.
  final int helpingApprovals;

  /// The keystore lost the old key, so the old names could not be read. It
  /// stays set until the UI calls [HelpersNotifier.acknowledgeKeystoreReset].
  final bool keystoreReset;

  HelpersState copyWith({
    HelpersView? view,
    String? error,
    bool clearError = false,
    bool? helpOthers,
    int? helpingApprovals,
    bool? keystoreReset,
  }) => HelpersState(
    view: view ?? this.view,
    error: clearError ? null : (error ?? this.error),
    helpOthers: helpOthers ?? this.helpOthers,
    helpingApprovals: helpingApprovals ?? this.helpingApprovals,
    keystoreReset: keystoreReset ?? this.keystoreReset,
  );
}

/// The app's side of helper invites. Every operation goes to lantern-core's
/// engine through [LanternService.helperCall]. Links, names and codes are
/// never logged.
@Riverpod(keepAlive: true)
class HelpersNotifier extends _$HelpersNotifier {
  /// Set once the user has used helper invites, so the keystore is never
  /// touched for anyone else.
  static const usedKey = 'helper_invites_used';

  @visibleForTesting
  static Duration pollInterval = const Duration(seconds: 30);

  /// How long a launch refresh waits for the core before trying anyway.
  @visibleForTesting
  static Duration radianceWait = const Duration(seconds: 30);

  /// Lets a test play a stealth build. Production reads the const.
  @visibleForTesting
  static bool? debugBuildEnabled;

  static bool get _buildEnabled =>
      debugBuildEnabled ?? AppBuildInfo.enableHelperInvites;

  Timer? _poll;
  Future<void>? _unlocking;

  /// Whether the engine has accepted the key. Kept apart from the view's
  /// `unlocked`, so a relock does not wipe the lists on screen.
  bool _engineUnlocked = false;

  /// Each engine request's number, so a view that was requested before the
  /// last applied one cannot overwrite it.
  int _sent = 0;
  int _applied = 0;
  String? _heldLink;

  /// Holds an invite link that opened the app, for HelpFriend to take, so
  /// the secret never travels in route arguments. Memory only.
  void holdLink(String link) => _heldLink = link;

  /// Returns the held link once, and forgets it.
  String? takeLink() {
    final link = _heldLink;
    _heldLink = null;
    return link;
  }

  @override
  HelpersState build() {
    ref.onDispose(() => _poll?.cancel());
    return const HelpersState();
  }

  LanternService get _svc => ref.read(lanternServiceProvider);

  LocalStorageService get _storage => sl<LocalStorageService>();

  bool get used => _storage.getBool(usedKey) ?? false;

  @visibleForTesting
  bool get polling => _poll != null;

  Future<_Answer> _send(String op, Map<String, dynamic> args) async {
    final seq = ++_sent;
    final res = await _svc.helperCall(op, args);
    return (
      res.fold((_) => HelperResult.failure('unavailable'), HelperResult.parse),
      seq,
    );
  }

  /// Calls the engine. When the engine answers `locked` (lantern-core
  /// restarted under us), it unlocks again and retries once. That is safe
  /// for every op: the engine refuses a locked call before running it.
  Future<_Answer> _call(
    String op, [
    Map<String, dynamic> args = const {},
  ]) async {
    if (!_buildEnabled) {
      return (HelperResult.failure('unavailable'), 0);
    }
    var a = await _send(op, args);
    if (a.$1.error != 'locked' || op == 'unlock' || !used) return a;
    _engineUnlocked = false;
    if (!await ensureUnlocked()) {
      return (HelperResult.failure(state.error ?? 'unavailable'), 0);
    }
    a = await _send(op, args);
    if (a.$1.error == 'locked') return (HelperResult.failure('unavailable'), 0);
    return a;
  }

  /// Applies an answer. A view replaces the view unless a later-requested
  /// view was already applied; an error is kept. A view's new_helping is
  /// counted even when the view itself is too old: the engine reports it
  /// once, so dropping it would lose the approval.
  HelperResult _apply(_Answer a, {bool isView = true}) {
    final (r, seq) = a;
    if (!ref.mounted) return r;
    if (!r.ok) {
      state = state.copyWith(error: r.error);
      return r;
    }
    if (isView) {
      if (seq < _applied) {
        if (r.data['new_helping'] == true) {
          state = state.copyWith(helpingApprovals: state.helpingApprovals + 1);
        }
        return r;
      }
      _applied = seq;
      final view = HelpersView.fromJson(r.data);
      state = state.copyWith(
        view: view,
        clearError: true,
        helpingApprovals: view.newHelping ? state.helpingApprovals + 1 : null,
      );
      _schedulePoll(view);
    } else {
      state = state.copyWith(clearError: true);
    }
    return r;
  }

  /// Unlocks the engine with the keystore key, once.
  Future<bool> ensureUnlocked() async {
    if (!_buildEnabled) return false;
    if (_engineUnlocked) return true;
    await (_unlocking ??= _unlock().whenComplete(() => _unlocking = null));
    return _engineUnlocked;
  }

  /// Clears [HelpersState.keystoreReset] once the user has seen it.
  void acknowledgeKeystoreReset() =>
      state = state.copyWith(keystoreReset: false);

  Future<void> _unlock() async {
    await _storage.setBool(usedKey, true);
    final String key;
    try {
      key = await sl<HelperKeyStore>().stateKey();
    } catch (_) {
      appLogger.error('helper: the OS keystore is unavailable');
      if (ref.mounted) state = state.copyWith(error: 'keystore');
      return;
    }
    final r = _apply(await _call('unlock', {'key': key}));
    _engineUnlocked = r.ok && r.data['unlocked'] == true;
    if (r.ok && r.data['keystore_reset'] == true && ref.mounted) {
      // The keystore returned a new key: the old names could not be read and
      // were set aside. Tell the user once they look.
      state = state.copyWith(keystoreReset: true);
    }
  }

  Future<HelperResult?> _guard() async {
    if (!_buildEnabled) return HelperResult.failure('unavailable');
    if (await ensureUnlocked()) return null;
    return HelperResult.failure(state.error ?? 'keystore');
  }

  Future<HelperResult> refresh() async {
    final locked = await _guard();
    if (locked != null) return locked;
    final r = _apply(await _call('refresh'));
    if (r.ok &&
        (r.data['new_helping'] == true || r.data['helpers_changed'] == true)) {
      // A new person to help: fetch the config that turns the widget on for
      // paired volunteers, then the features that show its tab. A helper
      // added or ended elsewhere: fetch the config that carries (or drops)
      // that helper's route.
      unawaited(_refetchConfig());
    }
    return r;
  }

  Future<void> _refetchConfig() async {
    try {
      final res = await _svc.sendConfigRequest();
      if (res.isLeft()) {
        // The feature flags cached now are the stale ones; radiance's own
        // config poll fetches both later.
        appLogger.error('helper: refetching config failed');
        return;
      }
      if (ref.mounted) {
        await ref.read(featureFlagProvider.notifier).fetchFeatureFlags();
      }
    } catch (_) {
      appLogger.error('helper: refetching config failed');
    }
  }

  /// Refreshes only on a device that has used helper invites, in a build
  /// that has them. At launch the core may still be starting (Android), so
  /// it waits for it first; anyone else never waits.
  Future<void> refreshIfUsed() async {
    if (!_buildEnabled || !used) return;
    try {
      await _svc.waitForRadiance().timeout(radianceWait);
    } catch (_) {
      appLogger.warning('helper: the core is not ready; refreshing anyway');
    }
    if (!ref.mounted) return;
    await refresh();
  }

  Future<HelperResult> refreshView() async => _apply(await _call('view'));

  Future<HelperResult> createInvite(String name) async {
    final locked = await _guard();
    if (locked != null) return locked;
    final r = _apply(
      await _call('create_invite', {'name': name}),
      isView: false,
    );
    if (!r.ok) return r;
    // The share screen reads the new invite from the view: without it, the
    // invite (kept by the engine) shows at the next view instead.
    var v = await refreshView();
    if (!v.ok && ref.mounted) v = await refreshView();
    return v.ok ? r : v;
  }

  Future<HelperResult> decide(String inviteId, {required bool approve}) async {
    final r = _apply(
      await _call('decide', {'invite_id': inviteId, 'approve': approve}),
    );
    // The new helper's route comes with the config: fetch it now rather
    // than at the next poll.
    if (r.ok && approve) unawaited(_refetchConfig());
    return r;
  }

  Future<HelperResult> forgetInvite(String inviteId) async =>
      _apply(await _call('forget_invite', {'invite_id': inviteId}));

  Future<HelperResult> claim(String link, String name) async {
    final locked = await _guard();
    if (locked != null) return locked;
    final r = _apply(
      await _call('claim', {'link': link, 'name': name}),
      isView: false,
    );
    if (!r.ok) return r;
    // The claim waits on the inviter, so poll for the answer even when the
    // view that would have started polling fails.
    final v = await refreshView();
    if (!v.ok && ref.mounted) _startPoll();
    return r;
  }

  Future<HelperResult> endPairing(String pairingId) async => _refetchIfOk(
    _apply(await _call('end_pairing', {'pairing_id': pairingId})),
  );

  /// The engine erases the names before it contacts lantern-cloud, so when
  /// the network step fails the local view (already without them) is shown,
  /// with the original error kept. When that view fails too, the names are
  /// erased from the one on screen.
  Future<HelperResult> endAllHelpers() async {
    final r = _refetchIfOk(_apply(await _call('end_all_helpers')));
    if (r.ok || !ref.mounted) return r;
    final v = await refreshView();
    if (!ref.mounted) return r;
    state = state.copyWith(
      view: v.ok ? null : _withoutHelperNames(state.view),
      error: r.error,
    );
    return r;
  }

  /// [view] without the names the engine erases in "remove all helpers".
  static HelpersView _withoutHelperNames(HelpersView view) => HelpersView(
    unlocked: view.unlocked,
    myName: view.myName,
    invites: [
      for (final i in view.invites)
        HelperInviteView(
          id: i.id,
          state: i.state,
          link: i.link,
          expiresUnix: i.expiresUnix,
          code: i.code,
          inviterName: i.inviterName,
        ),
    ],
    claims: view.claims,
    helpers: [
      for (final h in view.helpers)
        HelperPairingView(
          pairingId: h.pairingId,
          online: h.online,
          sinceUnix: h.sinceUnix,
        ),
    ],
    helping: view.helping,
    activity: view.activity,
  );

  /// After an ended pairing, fetch the config so its route goes now.
  HelperResult _refetchIfOk(HelperResult r) {
    if (r.ok) unawaited(_refetchConfig());
    return r;
  }

  /// Counts completed writes of "help others too", so a read that started
  /// before one cannot overwrite it.
  int _helpOthersWrites = 0;

  Future<void> loadHelpOthers() async {
    final writes = _helpOthersWrites;
    final res = await _svc.getSettings();
    if (!ref.mounted || writes != _helpOthersWrites) return;
    res.fold((_) {}, (s) {
      final v = s['peer_serve_pool'];
      state = state.copyWith(helpOthers: v is bool ? v : true);
    });
  }

  Future<void> setHelpOthers(bool value) async {
    final res = await _svc.patchSettings({'peer_serve_pool': value});
    if (!ref.mounted) return;
    res.fold(
      (f) =>
          appLogger.error('helper: setting help-others-too failed: ${f.error}'),
      (_) {
        _helpOthersWrites++;
        state = state.copyWith(helpOthers: value);
      },
    );
  }

  void _schedulePoll(HelpersView view) {
    if (!view.needsPolling) {
      _poll?.cancel();
      _poll = null;
      return;
    }
    _startPoll();
  }

  void _startPoll() {
    _poll ??= Timer.periodic(pollInterval, (_) {
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return;
      }
      unawaited(refresh());
    });
  }
}

typedef _Answer = (HelperResult, int);
