import 'package:objectbox/objectbox.dart';

@Entity()
class UserResponseEntity {
  int id;
  int legacyID;
  String legacyToken;
  bool emailConfirmed;
  bool success;
  final legacyUserData = ToOne<UserDataEntity>();
  final devices = ToMany<DeviceEntity>();

  UserResponseEntity({
    this.id = 0,
    required this.legacyID,
    required this.legacyToken,
    required this.emailConfirmed,
    required this.success,
  });
}

@Entity()
class DeviceEntity {
  int id;
  String deviceId;
  String name;
  int created;

  DeviceEntity({
    this.id = 0,
    required this.deviceId,
    required this.name,
    required this.created,
  });
}

@Entity()
class UserDataEntity {
  int id;
  int userId;
  String code;
  String token;
  String referral;
  String phone;
  String email;
  String userStatus;
  String userLevel;
  String locale;
  int expiration;
  String subscription;
  String bonusDays;
  String bonusMonths;
  bool yinbiEnabled;
  String servers;
  String inviters;
  String invitees;
  final devices = ToMany<DeviceEntity>();
  String purchases;
  final subscriptionData = ToOne<SubscriptionDataEntity>();
  final String deviceID;

  UserDataEntity({
    this.id = 0,
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
  });
}

@Entity()
class PurchaseEntity {
  int id;
  String plan;

  PurchaseEntity({
    this.id = 0,
    required this.plan,
  });
}

@Entity()
class SubscriptionDataEntity {
  int id;
  String planID;
  String stripeCustomerID;
  String startAt;
  String cancelledAt;
  bool autoRenew;
  String subscriptionID;
  String status;
  String provider;
  String createdAt;
  String endAt;

  SubscriptionDataEntity({
    this.id = 0,
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
}
