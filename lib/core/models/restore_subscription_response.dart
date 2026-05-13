import 'package:lantern/core/models/user.dart';

class RestoreSubscriptionResponse {
  final String status;
  final int actualUserId;
  final String actualUserToken;
  final List<DeviceModel> devices;

  RestoreSubscriptionResponse({
    required this.status,
    required this.actualUserId,
    required this.actualUserToken,
    required this.devices,
  });

  factory RestoreSubscriptionResponse.fromJson(Map<String, dynamic> json) =>
      RestoreSubscriptionResponse(
        status: (json['status'] as String?) ?? '',
        actualUserId: (json['actualUserId'] as num?)?.toInt() ?? 0,
        actualUserToken: (json['actualUserToken'] as String?) ?? '',
        devices: ((json['devices'] as List?) ?? const [])
            .whereType<Map>()
            .map((d) => DeviceModel.fromJson(Map<String, dynamic>.from(d)))
            .toList(),
      );

  bool get isAccountSwitch => actualUserId != 0 && actualUserToken.isNotEmpty;
}
