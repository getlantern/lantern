import 'package:lantern/core/models/user_entity.dart';
import 'package:lantern/lantern/protos/protos/auth.pbserver.dart';

extension UserMapper on LoginResponse {
  LoginResponseEntity toEntity() {
    final login = LoginResponseEntity(
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
}

extension UserDataMapper on LoginResponse_UserData {
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
    );
    user.devices.addAll(devices.map((e) => e.toEntity()));
    user.purchases.addAll(purchases.map((e) => e.toEntity()));
    return user;
  }
}

extension DeviceMapper on LoginResponse_Device {
  DeviceEntity toEntity() {
    return DeviceEntity(
      id: 0,
      deviceId: id,
      name: name,
      created: created.toInt(),
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
