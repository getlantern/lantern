import 'package:fixnum/fixnum.dart';
import 'package:lantern/core/models/entity/user_entity.dart';
import 'package:lantern/lantern/protos/protos/auth.pbserver.dart';

extension UserMapper on UserResponse {
  UserResponseEntity toEntity() {
    final login = UserResponseEntity(
      id: 0,
      legacyID: legacyID.toInt(),
      legacyToken: legacyToken,
      emailConfirmed: emailConfirmed,
      success: success,
    );
    login.legacyUserData.target = legacyUserData.toEntity();
    login.devices.addAll(devices.map((e) => e.toEntity()));
    return login;
  }

  bool isPro() {
    return legacyUserData.userStatus == 'pro';
  }
}

extension UserDataMapper on UserResponse_UserData {
  UserDataEntity toEntity() {
    final user = UserDataEntity(
      id: 0,
      userId: userId.toInt(),
      code: code,
      token: token,
      referral: referral,
      phone: phone,
      email: email,
      userStatus: userStatus,
      userLevel: userLevel,
      locale: locale,
      expiration: expiration.toInt(),
      subscription: subscription,
      bonusDays: bonusDays,
      bonusMonths: bonusMonths,
      yinbiEnabled: yinbiEnabled,
      servers: servers.toList().join(','),
      inviters: inviters.toList().join(','),
      invitees: invitees.toList().join(','),
      purchases: purchases.toList().join(','),
      deviceID: deviceID,
    );
    user.devices.addAll(devices.map((e) => e.toEntity()));

    user.subscriptionData.target = subscriptionData.toEntity();
    return user;
  }

  bool isPro() {
    return userLevel == 'pro';
  }
}

extension DeviceMapper on UserResponse_Device {
  DeviceEntity toEntity() {
    return DeviceEntity(
      id: 0,
      deviceId: id,
      name: name,
      created: created.toInt(),
    );
  }
}

extension SubscriptionDataMapper on UserResponse_UserData_SubscriptionData {
  SubscriptionDataEntity toEntity() {
    return SubscriptionDataEntity(
      id: 0,
      autoRenew: autoRenew,
      provider: provider,
      endAt: endAt.toString(),
      planID: planID,
      status: status,
      startAt: startAt.toString(),
      cancelledAt: cancelledAt.toString(),
      createdAt: createdAt.toString(),
      stripeCustomerID: stripeCustomerID,
      subscriptionID: subscriptionID,
    );
  }
}

extension PurchaseMapper on Purchase {
  PurchaseEntity toEntity() {
    return PurchaseEntity(
      id: 0,
      plan: plan,
    );
  }
}

extension LoginUserData on UserResponseEntity {
  UserResponse toUserResponse() {
    return UserResponse(
      id: id.toString(),
      legacyID: Int64(legacyID),
      legacyToken: legacyToken,
      emailConfirmed: emailConfirmed,
      success: success,
      legacyUserData: legacyUserData.target!.toUserData(),
      devices: devices.map((e) => e.toDevice()).toList(),
    );
  }
}

extension UserData on UserDataEntity {
  UserResponse_UserData toUserData() {
    return UserResponse_UserData(
      userId: Int64(userId),
      code: code,
      token: token,
      referral: referral,
      phone: phone,
      email: email,
      userStatus: userStatus,
      userLevel: userLevel,
      locale: locale,
      expiration: Int64(expiration),
      subscription: subscription,
      bonusDays: bonusDays,
      bonusMonths: bonusMonths,
      yinbiEnabled: yinbiEnabled,
      servers: servers.split(',').toList(),
      inviters: inviters.split(',').toList(),
      invitees: invitees.split(',').toList(),
      devices: devices.map((e) => e.toDevice()).toList(),
      purchases: purchases.split(',').toList(),
      subscriptionData: subscriptionData.target!.toSubscriptionData(),
      deviceID: deviceID,
    );
  }
}

extension DeviceExtension on DeviceEntity {
  UserResponse_Device toDevice() {
    return UserResponse_Device(
      id: deviceId,
      name: name,
      created: Int64(created),
    );
  }
}

extension PurchaseExtension on PurchaseEntity {
  Purchase toPurchase() {
    return Purchase(
      plan: plan,
    );
  }
}

extension SubscriptionDataExtension on SubscriptionDataEntity {
  UserResponse_UserData_SubscriptionData toSubscriptionData() {
    return UserResponse_UserData_SubscriptionData(
      autoRenew: autoRenew,
      provider: provider,
      endAt: Int64(int.parse(endAt)) ,
      planID: planID,
      status: status,
      startAt: Int64(int.parse(startAt)) ,
      cancelledAt: Int64(int.parse(cancelledAt)) ,
      createdAt: Int64(int.parse(createdAt)) ,
      stripeCustomerID: stripeCustomerID,
      subscriptionID: subscriptionID,
    );
  }
}
