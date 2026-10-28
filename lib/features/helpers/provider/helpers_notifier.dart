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
  });

  final HelpersView view;

  /// The last operation's error code, cleared by the next success.
  final String? error;

  /// "Help others too" (radiance peer_serve_pool; unset means on).
  final bool helpOthers;

  /// Counts refreshes that found a new pairing this device helps. Home starts
  /// sharing when it grows.
  final int helpingApprovals;

  HelpersState copyWith({
    HelpersView? view,
    String? error,
    bool clearError = false,
    bool? helpOthers,
    int? helpingApprovals,
  }) => HelpersState(
    view: view ?? this.view,
    error: clearError ? null : (error ?? this.error),
    helpOthers: helpOthers ?? this.helpOthers,
    helpingApprovals: helpingApprovals ?? this.helpingApprovals,
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

  Timer? _poll;
  Future<void>? _unlocking;
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

  Future<HelperResult> _call(
    String op, [
    Map<String, dynamic> args = const {},
  ]) async {
    final res = await _svc.helperCall(op, args);
    return res.fold(
      (_) => HelperResult.failure('unavailable'),
      HelperResult.parse,
    );
  }

  /// Applies a result. A view result replaces the view; an error is kept.
  HelperResult _apply(HelperResult r, {bool isView = true}) {
    if (!ref.mounted) return r;
    if (!r.ok) {
      state = state.copyWith(error: r.error);
      return r;
    }
    if (isView) {
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
    if (state.view.unlocked) return true;
    await (_unlocking ??= _unlock().whenComplete(() => _unlocking = null));
    return state.view.unlocked;
  }

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
    if (r.ok && r.data['keystore_reset'] == true && ref.mounted) {
      // The keystore returned a new key: the old names could not be read and
      // were set aside. Tell the user once.
      state = state.copyWith(error: 'keystore_reset');
    }
  }

  Future<HelperResult?> _guard() async {
    if (await ensureUnlocked()) return null;
    return HelperResult.failure(state.error ?? 'keystore');
  }

  Future<HelperResult> refresh() async {
    final locked = await _guard();
    if (locked != null) return locked;
    final r = _apply(await _call('refresh'));
    if (r.ok && r.data['new_helping'] == true) {
      // A new person to help: fetch the config that turns the widget on for
      // paired volunteers, then the features that show its tab.
      unawaited(
        _svc.sendConfigRequest().then((_) {
          if (ref.mounted) {
            ref.read(featureFlagProvider.notifier).fetchFeatureFlags();
          }
        }),
      );
    }
    return r;
  }

  /// Refreshes only on a device that has used helper invites, in a build
  /// that has them.
  Future<void> refreshIfUsed() async {
    if (AppBuildInfo.enableHelperInvites && used) await refresh();
  }

  Future<HelperResult> refreshView() async => _apply(await _call('view'));

  Future<HelperResult> createInvite(String name) async {
    final locked = await _guard();
    if (locked != null) return locked;
    final r = _apply(
      await _call('create_invite', {'name': name}),
      isView: false,
    );
    if (r.ok) await refreshView();
    return r;
  }

  Future<HelperResult> decide(String inviteId, {required bool approve}) async =>
      _apply(
        await _call('decide', {'invite_id': inviteId, 'approve': approve}),
      );

  Future<HelperResult> forgetInvite(String inviteId) async =>
      _apply(await _call('forget_invite', {'invite_id': inviteId}));

  Future<HelperResult> claim(String link, String name) async {
    final locked = await _guard();
    if (locked != null) return locked;
    final r = _apply(
      await _call('claim', {'link': link, 'name': name}),
      isView: false,
    );
    if (r.ok) await refreshView();
    return r;
  }

  Future<HelperResult> endPairing(String pairingId) async =>
      _apply(await _call('end_pairing', {'pairing_id': pairingId}));

  Future<HelperResult> endAllHelpers() async =>
      _apply(await _call('end_all_helpers'));

  Future<void> loadHelpOthers() async {
    final res = await _svc.getSettings();
    if (!ref.mounted) return;
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
      (_) => state = state.copyWith(helpOthers: value),
    );
  }

  void _schedulePoll(HelpersView view) {
    if (!view.needsPolling) {
      _poll?.cancel();
      _poll = null;
      return;
    }
    _poll ??= Timer.periodic(pollInterval, (_) {
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return;
      }
      unawaited(refresh());
    });
  }
}
