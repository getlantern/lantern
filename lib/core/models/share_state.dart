/// Which protocol the user is sharing through.
///
/// off: not sharing, or probe in flight. unbounded: broflake/WebRTC relay.
/// smc: samizdat-over-UPnP "Share My Connection", where the user's own IP is
/// the exit.
enum ShareMode { off, unbounded, smc }

/// SmC lifecycle phase from radiance peer.Status. Wire strings must stay in
/// sync with radiance/peer/peer.go.
enum SharePhase {
  idle,
  mappingPort,
  detectingIp,
  registering,
  startingProxy,
  verifying,
  serving,
  stopping,
  error;

  static SharePhase fromWire(String? s) => switch (s) {
        'mapping_port' => SharePhase.mappingPort,
        'detecting_ip' => SharePhase.detectingIp,
        'registering' => SharePhase.registering,
        'starting_proxy' => SharePhase.startingProxy,
        'verifying' => SharePhase.verifying,
        'serving' => SharePhase.serving,
        'stopping' => SharePhase.stopping,
        'error' => SharePhase.error,
        _ => SharePhase.idle,
      };
}

class ShareState {
  final bool active;
  final bool probing;
  final bool unboundedRunning;
  final ShareMode mode;
  final int activeCount;
  final int totalCount;
  /// SmC only; Unbounded reports readiness via [unboundedRunning].
  final SharePhase phase;
  final String? errorMessage;

  const ShareState({
    this.active = false,
    this.probing = false,
    this.unboundedRunning = false,
    this.mode = ShareMode.off,
    this.activeCount = 0,
    this.totalCount = 0,
    this.phase = SharePhase.idle,
    this.errorMessage,
  });

  ShareState copyWith({
    bool? active,
    bool? probing,
    bool? unboundedRunning,
    ShareMode? mode,
    int? activeCount,
    int? totalCount,
    SharePhase? phase,
    // Sentinel default so callers can clear the message by passing null.
    Object? errorMessage = _unsetErrorMessage,
  }) =>
      ShareState(
        active: active ?? this.active,
        probing: probing ?? this.probing,
        unboundedRunning: unboundedRunning ?? this.unboundedRunning,
        mode: mode ?? this.mode,
        activeCount: activeCount ?? this.activeCount,
        totalCount: totalCount ?? this.totalCount,
        phase: phase ?? this.phase,
        errorMessage: identical(errorMessage, _unsetErrorMessage)
            ? this.errorMessage
            : errorMessage as String?,
      );
}

class _UnsetErrorMessage {
  const _UnsetErrorMessage();
}

const _unsetErrorMessage = _UnsetErrorMessage();
