class UserResponseModel {
  final int legacyID;
  final String legacyToken;
  final bool emailConfirmed;
  final bool success;
  final UserDataModel? legacyUserData;
  final List<DeviceModel> devices;

  const UserResponseModel({
    required this.legacyID,
    required this.legacyToken,
    required this.emailConfirmed,
    required this.success,
    this.legacyUserData,
    this.devices = const [],
  });

  factory UserResponseModel.fromJson(Map<String, dynamic> json) =>
      UserResponseModel(
        legacyID: (json['legacyID'] as num?)?.toInt() ?? 0,
        legacyToken: (json['legacyToken'] ?? '').toString(),
        emailConfirmed: json['emailConfirmed'] == true,
        success: json['success'] == true,
        legacyUserData: json['legacyUserData'] is Map
            ? UserDataModel.fromJson(
                Map<String, dynamic>.from(json['legacyUserData'] as Map),
              )
            : null,
        devices: ((json['devices'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => DeviceModel.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'legacyID': legacyID,
        'legacyToken': legacyToken,
        'emailConfirmed': emailConfirmed,
        'success': success,
        'legacyUserData': legacyUserData?.toJson(),
        'devices': devices.map((d) => d.toJson()).toList(),
      };
}

class DeviceModel {
  final String deviceId;
  final String name;
  final int created;

  const DeviceModel({
    required this.deviceId,
    required this.name,
    required this.created,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) => DeviceModel(
        deviceId: (json['deviceId'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        created: (json['created'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'name': name,
        'created': created,
      };
}

class UserDataModel {
  final int userId;
  final String code;
  final String token;
  final String referral;
  final String phone;
  final String email;
  final String userStatus;
  final String userLevel;
  final String locale;
  final int expiration;
  final String subscription;
  final String bonusDays;
  final String bonusMonths;
  final bool yinbiEnabled;
  final String servers;
  final String inviters;
  final String invitees;
  final List<DeviceModel> devices;
  final String purchases; // consider List<PurchaseModel> instead
  final SubscriptionDataModel? subscriptionData;
  final String deviceID;
  final bool unpassRegistered;
  final int lastExpiredOn;

  const UserDataModel({
    required this.userId,
    required this.code,
    required this.token,
    required this.referral,
    required this.phone,
    required this.email,
    required this.userStatus,
    required this.userLevel,
    required this.locale,
    required this.expiration,
    required this.subscription,
    required this.bonusDays,
    required this.bonusMonths,
    required this.yinbiEnabled,
    required this.servers,
    required this.inviters,
    required this.invitees,
    required this.purchases,
    required this.deviceID,
    required this.unpassRegistered,
    required this.lastExpiredOn,
    this.devices = const [],
    this.subscriptionData,
  });

  factory UserDataModel.fromJson(Map<String, dynamic> json) => UserDataModel(
        userId: (json['userId'] as num?)?.toInt() ?? 0,
        code: (json['code'] ?? '').toString(),
        token: (json['token'] ?? '').toString(),
        referral: (json['referral'] ?? '').toString(),
        phone: (json['phone'] ?? '').toString(),
        email: (json['email'] ?? '').toString(),
        userStatus: (json['userStatus'] ?? '').toString(),
        userLevel: (json['userLevel'] ?? '').toString(),
        locale: (json['locale'] ?? '').toString(),
        expiration: (json['expiration'] as num?)?.toInt() ?? 0,
        subscription: (json['subscription'] ?? '').toString(),
        bonusDays: (json['bonusDays'] ?? '').toString(),
        bonusMonths: (json['bonusMonths'] ?? '').toString(),
        yinbiEnabled: json['yinbiEnabled'] == true,
        servers: (json['servers'] ?? '').toString(),
        inviters: (json['inviters'] ?? '').toString(),
        invitees: (json['invitees'] ?? '').toString(),
        purchases: (json['purchases'] ?? '').toString(),
        deviceID: (json['deviceID'] ?? '').toString(),
        unpassRegistered: json['unpassRegistered'] == true,
        lastExpiredOn: (json['lastExpiredOn'] as num?)?.toInt() ?? 0,
        devices: ((json['devices'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => DeviceModel.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
        subscriptionData: json['subscriptionData'] is Map
            ? SubscriptionDataModel.fromJson(
                Map<String, dynamic>.from(json['subscriptionData'] as Map),
              )
            : null,
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'code': code,
        'token': token,
        'referral': referral,
        'phone': phone,
        'email': email,
        'userStatus': userStatus,
        'userLevel': userLevel,
        'locale': locale,
        'expiration': expiration,
        'subscription': subscription,
        'bonusDays': bonusDays,
        'bonusMonths': bonusMonths,
        'yinbiEnabled': yinbiEnabled,
        'servers': servers,
        'inviters': inviters,
        'invitees': invitees,
        'devices': devices.map((d) => d.toJson()).toList(),
        'purchases': purchases,
        'subscriptionData': subscriptionData?.toJson(),
        'deviceID': deviceID,
        'unpassRegistered': unpassRegistered,
        'lastExpiredOn': lastExpiredOn,
      };
}

class SubscriptionDataModel {
  final String planID;
  final String stripeCustomerID;
  final String startAt;
  final String cancelledAt;
  final bool autoRenew;
  final String subscriptionID;
  final String status;
  final String provider;
  final String createdAt;
  final String endAt;

  const SubscriptionDataModel({
    required this.planID,
    required this.stripeCustomerID,
    required this.startAt,
    required this.cancelledAt,
    required this.autoRenew,
    required this.subscriptionID,
    required this.status,
    required this.provider,
    required this.createdAt,
    required this.endAt,
  });

  factory SubscriptionDataModel.fromJson(Map<String, dynamic> json) =>
      SubscriptionDataModel(
        planID: (json['planID'] ?? '').toString(),
        stripeCustomerID: (json['stripeCustomerID'] ?? '').toString(),
        startAt: (json['startAt'] ?? '').toString(),
        cancelledAt: (json['cancelledAt'] ?? '').toString(),
        autoRenew: json['autoRenew'] == true,
        subscriptionID: (json['subscriptionID'] ?? '').toString(),
        status: (json['status'] ?? '').toString(),
        provider: (json['provider'] ?? '').toString(),
        createdAt: (json['createdAt'] ?? '').toString(),
        endAt: (json['endAt'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'planID': planID,
        'stripeCustomerID': stripeCustomerID,
        'startAt': startAt,
        'cancelledAt': cancelledAt,
        'autoRenew': autoRenew,
        'subscriptionID': subscriptionID,
        'status': status,
        'provider': provider,
        'createdAt': createdAt,
        'endAt': endAt,
      };
}
