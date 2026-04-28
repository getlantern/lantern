class UserResponseModel {
  final String id;
  final int legacyID;
  final String legacyToken;
  final bool emailConfirmed;
  final bool success;
  final UserDataModel legacyUserData;
  final List<DeviceModel> devices;

  const UserResponseModel({
    this.id = '',
    required this.legacyID,
    required this.legacyToken,
    required this.emailConfirmed,
    required this.success,
    this.legacyUserData = const UserDataModel(),
    this.devices = const [],
  });

  factory UserResponseModel.fromJson(Map<String, dynamic> json) =>
      UserResponseModel(
        id: (json['id'] ?? '').toString(),
        legacyID: (json['legacyID'] as num?)?.toInt() ?? 0,
        legacyToken: (json['legacyToken'] ?? '').toString(),
        emailConfirmed: json['emailConfirmed'] == true,
        success: (json['success'] == true || json['Success'] == true),
        legacyUserData: json['legacyUserData'] is Map
            ? UserDataModel.fromJson(
                Map<String, dynamic>.from(json['legacyUserData'] as Map),
              )
            : const UserDataModel(),
        devices: ((json['devices'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => DeviceModel.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'legacyID': legacyID,
    'legacyToken': legacyToken,
    'emailConfirmed': emailConfirmed,
    'success': success,
    'legacyUserData': legacyUserData.toJson(),
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
    deviceId: (json['id'] ?? '').toString(),
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
  final String purchases;
  final SubscriptionDataModel subscriptionData;
  final String deviceID;
  final bool unpassRegistered;
  final int lastExpiredOn;

  const UserDataModel({
    this.userId = 0,
    this.code = '',
    this.token = '',
    this.referral = '',
    this.phone = '',
    this.email = '',
    this.userStatus = '',
    this.userLevel = '',
    this.locale = '',
    this.expiration = 0,
    this.subscription = '',
    this.bonusDays = '',
    this.bonusMonths = '',
    this.yinbiEnabled = false,
    this.servers = '',
    this.inviters = '',
    this.invitees = '',
    this.purchases = '',
    this.deviceID = '',
    this.unpassRegistered = false,
    this.lastExpiredOn = 0,
    this.devices = const [],
    this.subscriptionData = const SubscriptionDataModel(),
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
        .map((m) => DeviceModel.fromJson(Map<String, dynamic>.from(m)))
        .toList(),
    subscriptionData: json['subscriptionData'] is Map
        ? SubscriptionDataModel.fromJson(
            Map<String, dynamic>.from(json['subscriptionData'] as Map),
          )
        : const SubscriptionDataModel(),
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
    'subscriptionData': subscriptionData.toJson(),
    'deviceID': deviceID,
    'unpassRegistered': unpassRegistered,
    'lastExpiredOn': lastExpiredOn,
  };
}

class SubscriptionDataModel {
  final String planID;
  final String stripeCustomerID;
  final int startAt;
  final int cancelledAt;
  final bool autoRenew;
  final String subscriptionID;
  final String status;
  final String provider;
  final int createdAt;
  final int endAt;

  const SubscriptionDataModel({
    this.planID = '',
    this.stripeCustomerID = '',
    this.startAt = 0,
    this.cancelledAt = 0,
    this.autoRenew = false,
    this.subscriptionID = '',
    this.status = '',
    this.provider = '',
    this.createdAt = 0,
    this.endAt = 0,
  });

  factory SubscriptionDataModel.fromJson(Map<String, dynamic> json) =>
      SubscriptionDataModel(
        planID: (json['planID'] ?? '').toString(),
        stripeCustomerID: (json['stripeCustomerID'] ?? '').toString(),
        startAt: (json['startAt'] as num?)?.toInt() ?? 0,
        cancelledAt: (json['cancelledAt'] as num?)?.toInt() ?? 0,
        autoRenew: json['autoRenew'] == true,
        subscriptionID: (json['subscriptionID'] ?? '').toString(),
        status: (json['status'] ?? '').toString(),
        provider: (json['provider'] ?? '').toString(),
        createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
        endAt: (json['endAt'] as num?)?.toInt() ?? 0,
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
