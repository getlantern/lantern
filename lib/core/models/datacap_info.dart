
class DataCapUsageResponse {
  /// Whether data cap is enabled for this device/user
  final bool enabled;

  /// Data cap usage details (only populated if enabled is true)
  final DataCapUsageDetails? usage;

  DataCapUsageResponse({
    required this.enabled,
    this.usage,
  });

  factory DataCapUsageResponse.fromJson(Map<String, dynamic> json) {
    return DataCapUsageResponse(
      enabled: json['enabled'] as bool,
      usage: json['usage'] != null
          ? DataCapUsageDetails.fromJson(json['usage'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      if (usage != null) 'usage': usage!.toJson(),
    };
  }

  @override
  String toString() {
    return 'GetDataCapUsageResponse(enabled: $enabled, usage: $usage)';
  }
}

/// Details of the data cap usage
class DataCapUsageDetails {
  final int bytesAllotted;
  final int bytesUsed;
  final String allotmentStartTime;
  final String allotmentEndTime;

  DataCapUsageDetails({
    required this.bytesAllotted,
    required this.bytesUsed,
    required this.allotmentStartTime,
    required this.allotmentEndTime,
  });

  factory DataCapUsageDetails.fromJson(Map<String, dynamic> json) {
    return DataCapUsageDetails(
      bytesAllotted:
          json['bytesAllotted'] != null && json['bytesAllotted'] != ""
              ? int.tryParse(json['bytesAllotted'].toString()) ?? 0
              : 0,
      bytesUsed: json['bytesUsed'] != null && json['bytesUsed'] != ""
          ? int.tryParse(json['bytesUsed'].toString()) ?? 0
          : 0,
      allotmentStartTime: json['allotmentStartTime'] as String,
      allotmentEndTime: json['allotmentEndTime'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bytesAllotted': bytesAllotted,
      'bytesUsed': bytesUsed,
      'allotmentStartTime': allotmentStartTime,
      'allotmentEndTime': allotmentEndTime,
    };
  }

  @override
  String toString() {
    return 'DataCapUsageDetails(bytesAllotted: $bytesAllotted, bytesUsed: $bytesUsed, '
        'allotmentStartTime: $allotmentStartTime, allotmentEndTime: $allotmentEndTime)';
  }
}
