class DataCapInfo {
  final int bytesAllotted;
  final int bytesRemaining;
  final DateTime allotmentStart;
  final DateTime allotmentEnd;

  DataCapInfo({
    required this.bytesAllotted,
    required this.bytesRemaining,
    required this.allotmentStart,
    required this.allotmentEnd,
  });

  factory DataCapInfo.fromJson(Map<String, dynamic> json) => DataCapInfo(
        bytesAllotted: json['bytesAllotted'] as int,
        bytesRemaining: json['bytesRemaining'] as int,
        allotmentStart:
            DateTime.fromMillisecondsSinceEpoch(json['allotmentStart'] * 1000),
        allotmentEnd:
            DateTime.fromMillisecondsSinceEpoch(json['allotmentEnd'] * 1000),
      );
}
