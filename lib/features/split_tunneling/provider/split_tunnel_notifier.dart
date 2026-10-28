import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/localization/i18n.dart';
import 'package:lantern/core/models/split_tunnel_state.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'split_tunnel_notifier.g.dart';

@Riverpod(keepAlive: true)
class SplitTunnel extends _$SplitTunnel {
  Future<void> _pending = Future.value();
  int _generation = 0;

  @override
  Future<SplitTunnelState> build() {
    final generation = ++_generation;
    return _enqueue(() async {
      final result = await ref
          .read(lanternServiceProvider)
          .getSplitTunnelState();
      final snapshot = result.fold(
        (failure) => throw failure,
        (snapshot) => snapshot,
      );
      if (ref.mounted && generation == _generation) state = AsyncData(snapshot);
      return snapshot;
    });
  }

  Future<Failure?> refresh() => _serialize(_refresh, requireState: false);

  Future<Failure?> _refresh() async {
    final generation = _generation;
    final result = await ref.read(lanternServiceProvider).getSplitTunnelState();
    if (!ref.mounted || generation != _generation) return null;
    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return failure;
      },
      (snapshot) {
        state = AsyncData(snapshot);
        return null;
      },
    );
  }

  Future<Failure?> _serialize(
    Future<Failure?> Function() action, {
    bool requireState = true,
  }) {
    return _enqueue(() async {
      try {
        if (!ref.mounted) return null;
        if (requireState) state.requireValue;
        return await action();
      } catch (error) {
        return error is Failure
            ? error
            : Failure(
                error: error.toString(),
                localizedErrorMessage: 'split_tunnel_update_failed'.i18n,
              );
      }
    });
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final next = _pending.then((_) => action());
    _pending = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<Failure?> _write(
    Future<Either<Failure, Unit>> Function() action,
  ) async {
    final result = await action();
    final failure = result.fold((failure) => failure, (_) => null);
    final refreshFailure = await _refresh();
    return failure ?? refreshFailure;
  }

  Future<Failure?> setEnabled(bool enabled) => _serialize(() async {
    if (state.requireValue.enabled == enabled) return null;
    return _write(
      () => ref.read(lanternServiceProvider).setSplitTunnelingEnabled(enabled),
    );
  });

  Future<Failure?> switchPolicy(SplitTunnelPolicy policy) =>
      _serialize(() async {
        final current = state.requireValue;
        if (current.policy == policy) return null;
        if (!current.supported) {
          return Failure(
            error: 'split_tunnel_unsupported',
            localizedErrorMessage: 'split_tunnel_update_required'.i18n,
          );
        }
        final generation = _generation;
        final result = await ref
            .read(lanternServiceProvider)
            .switchSplitTunnelPolicy(policy.wireValue);
        return result.fold(
          (failure) async {
            await _refresh();
            return failure;
          },
          (snapshot) async {
            if (ref.mounted && generation == _generation) {
              state = AsyncData(snapshot);
            }
            return null;
          },
        );
      });

  Future<Failure?> clearApps() => _serialize(() async {
    final generation = _generation;
    final result = await ref
        .read(lanternServiceProvider)
        .clearSplitTunnelApps();
    return result.fold(
      (failure) async {
        await _refresh();
        return failure;
      },
      (snapshot) async {
        if (ref.mounted && generation == _generation) {
          state = AsyncData(snapshot);
        }
        return null;
      },
    );
  });

  Future<Failure?> setSelector(
    SplitTunnelFilterType type,
    String value, {
    bool? selected,
  }) => _serialize(() {
    final current = state.requireValue.selectors(type).contains(value);
    final add = selected ?? !current;
    if (current == add) return Future.value();
    final service = ref.read(lanternServiceProvider);
    return _write(
      () => add
          ? service.addSplitTunnelItem(type, value)
          : service.removeSplitTunnelItem(type, value),
    );
  });
}
