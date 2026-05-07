/// Represents a consumer connection change from the broflake widget proxy.
class UnboundedConnectionEvent {
  final int state; // 1 = connected, -1 = disconnected
  final int workerIdx;
  final String addr; // IP address

  UnboundedConnectionEvent({
    required this.state,
    required this.workerIdx,
    required this.addr,
  });

  factory UnboundedConnectionEvent.fromJson(Map<String, dynamic> json) {
    return UnboundedConnectionEvent(
      state: json['state'] as int,
      workerIdx: json['workerIdx'] as int,
      addr: json['addr'] as String? ?? '',
    );
  }
}

/// Tracks live and cumulative connection counts for Unbounded.
class UnboundedStats {
  final int activeCount;
  final int totalCount;

  const UnboundedStats({this.activeCount = 0, this.totalCount = 0});
}
