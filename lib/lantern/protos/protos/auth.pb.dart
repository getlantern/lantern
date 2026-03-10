// This is a generated file - do not edit.
//
// Generated from protos/auth.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class UserResponse_Device extends $pb.GeneratedMessage {
  factory UserResponse_Device({
    $core.String? id,
    $core.String? name,
    $fixnum.Int64? created,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (created != null) result.created = created;
    return result;
  }

  UserResponse_Device._();

  factory UserResponse_Device.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UserResponse_Device.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UserResponse.Device',
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aInt64(3, _omitFieldNames ? '' : 'created')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserResponse_Device clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserResponse_Device copyWith(void Function(UserResponse_Device) updates) =>
      super.copyWith((message) => updates(message as UserResponse_Device))
          as UserResponse_Device;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UserResponse_Device create() => UserResponse_Device._();
  @$core.override
  UserResponse_Device createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UserResponse_Device getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UserResponse_Device>(create);
  static UserResponse_Device? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get created => $_getI64(2);
  @$pb.TagNumber(3)
  set created($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCreated() => $_has(2);
  @$pb.TagNumber(3)
  void clearCreated() => $_clearField(3);
}

class UserResponse_UserData_SubscriptionData extends $pb.GeneratedMessage {
  factory UserResponse_UserData_SubscriptionData({
    $core.String? subscriptionID,
    $core.String? planID,
    $core.String? stripeCustomerID,
    $core.String? status,
    $core.String? cancellationReason,
    $fixnum.Int64? createdAt,
    $fixnum.Int64? startAt,
    $fixnum.Int64? endAt,
    $fixnum.Int64? cancelledAt,
    $core.bool? autoRenew,
    $core.String? provider,
  }) {
    final result = create();
    if (subscriptionID != null) result.subscriptionID = subscriptionID;
    if (planID != null) result.planID = planID;
    if (stripeCustomerID != null) result.stripeCustomerID = stripeCustomerID;
    if (status != null) result.status = status;
    if (cancellationReason != null)
      result.cancellationReason = cancellationReason;
    if (createdAt != null) result.createdAt = createdAt;
    if (startAt != null) result.startAt = startAt;
    if (endAt != null) result.endAt = endAt;
    if (cancelledAt != null) result.cancelledAt = cancelledAt;
    if (autoRenew != null) result.autoRenew = autoRenew;
    if (provider != null) result.provider = provider;
    return result;
  }

  UserResponse_UserData_SubscriptionData._();

  factory UserResponse_UserData_SubscriptionData.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UserResponse_UserData_SubscriptionData.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UserResponse.UserData.SubscriptionData',
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'subscriptionID',
        protoName: 'subscriptionID')
    ..aOS(2, _omitFieldNames ? '' : 'planID', protoName: 'planID')
    ..aOS(3, _omitFieldNames ? '' : 'stripeCustomerID',
        protoName: 'stripeCustomerID')
    ..aOS(4, _omitFieldNames ? '' : 'status')
    ..aOS(5, _omitFieldNames ? '' : 'cancellationReason',
        protoName: 'cancellationReason')
    ..aInt64(6, _omitFieldNames ? '' : 'createdAt', protoName: 'createdAt')
    ..aInt64(7, _omitFieldNames ? '' : 'startAt', protoName: 'startAt')
    ..aInt64(8, _omitFieldNames ? '' : 'endAt', protoName: 'endAt')
    ..aInt64(9, _omitFieldNames ? '' : 'cancelledAt', protoName: 'cancelledAt')
    ..aOB(10, _omitFieldNames ? '' : 'autoRenew', protoName: 'autoRenew')
    ..aOS(11, _omitFieldNames ? '' : 'provider')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserResponse_UserData_SubscriptionData clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserResponse_UserData_SubscriptionData copyWith(
          void Function(UserResponse_UserData_SubscriptionData) updates) =>
      super.copyWith((message) =>
              updates(message as UserResponse_UserData_SubscriptionData))
          as UserResponse_UserData_SubscriptionData;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UserResponse_UserData_SubscriptionData create() =>
      UserResponse_UserData_SubscriptionData._();
  @$core.override
  UserResponse_UserData_SubscriptionData createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UserResponse_UserData_SubscriptionData getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<
          UserResponse_UserData_SubscriptionData>(create);
  static UserResponse_UserData_SubscriptionData? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get subscriptionID => $_getSZ(0);
  @$pb.TagNumber(1)
  set subscriptionID($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSubscriptionID() => $_has(0);
  @$pb.TagNumber(1)
  void clearSubscriptionID() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get planID => $_getSZ(1);
  @$pb.TagNumber(2)
  set planID($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPlanID() => $_has(1);
  @$pb.TagNumber(2)
  void clearPlanID() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get stripeCustomerID => $_getSZ(2);
  @$pb.TagNumber(3)
  set stripeCustomerID($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStripeCustomerID() => $_has(2);
  @$pb.TagNumber(3)
  void clearStripeCustomerID() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get status => $_getSZ(3);
  @$pb.TagNumber(4)
  set status($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasStatus() => $_has(3);
  @$pb.TagNumber(4)
  void clearStatus() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get cancellationReason => $_getSZ(4);
  @$pb.TagNumber(5)
  set cancellationReason($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCancellationReason() => $_has(4);
  @$pb.TagNumber(5)
  void clearCancellationReason() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get createdAt => $_getI64(5);
  @$pb.TagNumber(6)
  set createdAt($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCreatedAt() => $_has(5);
  @$pb.TagNumber(6)
  void clearCreatedAt() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get startAt => $_getI64(6);
  @$pb.TagNumber(7)
  set startAt($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasStartAt() => $_has(6);
  @$pb.TagNumber(7)
  void clearStartAt() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get endAt => $_getI64(7);
  @$pb.TagNumber(8)
  set endAt($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasEndAt() => $_has(7);
  @$pb.TagNumber(8)
  void clearEndAt() => $_clearField(8);

  @$pb.TagNumber(9)
  $fixnum.Int64 get cancelledAt => $_getI64(8);
  @$pb.TagNumber(9)
  set cancelledAt($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasCancelledAt() => $_has(8);
  @$pb.TagNumber(9)
  void clearCancelledAt() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get autoRenew => $_getBF(9);
  @$pb.TagNumber(10)
  set autoRenew($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasAutoRenew() => $_has(9);
  @$pb.TagNumber(10)
  void clearAutoRenew() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get provider => $_getSZ(10);
  @$pb.TagNumber(11)
  set provider($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasProvider() => $_has(10);
  @$pb.TagNumber(11)
  void clearProvider() => $_clearField(11);
}

class UserResponse_UserData extends $pb.GeneratedMessage {
  factory UserResponse_UserData({
    $fixnum.Int64? userId,
    $core.String? code,
    $core.String? token,
    $core.String? referral,
    @$core.Deprecated('This field is deprecated.') $core.String? phone,
    $core.String? email,
    $core.String? userStatus,
    $core.String? userLevel,
    $core.String? locale,
    $fixnum.Int64? expiration,
    $core.Iterable<$core.String>? servers,
    $core.String? subscription,
    $core.Iterable<$core.String>? purchases,
    $core.String? bonusDays,
    $core.String? bonusMonths,
    $core.Iterable<$core.String>? inviters,
    $core.Iterable<$core.String>? invitees,
    $core.Iterable<UserResponse_Device>? devices,
    $core.bool? yinbiEnabled,
    UserResponse_UserData_SubscriptionData? subscriptionData,
    $core.String? deviceID,
    $core.bool? unpassRegistered,
    $fixnum.Int64? lastExpiredOn,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (code != null) result.code = code;
    if (token != null) result.token = token;
    if (referral != null) result.referral = referral;
    if (phone != null) result.phone = phone;
    if (email != null) result.email = email;
    if (userStatus != null) result.userStatus = userStatus;
    if (userLevel != null) result.userLevel = userLevel;
    if (locale != null) result.locale = locale;
    if (expiration != null) result.expiration = expiration;
    if (servers != null) result.servers.addAll(servers);
    if (subscription != null) result.subscription = subscription;
    if (purchases != null) result.purchases.addAll(purchases);
    if (bonusDays != null) result.bonusDays = bonusDays;
    if (bonusMonths != null) result.bonusMonths = bonusMonths;
    if (inviters != null) result.inviters.addAll(inviters);
    if (invitees != null) result.invitees.addAll(invitees);
    if (devices != null) result.devices.addAll(devices);
    if (yinbiEnabled != null) result.yinbiEnabled = yinbiEnabled;
    if (subscriptionData != null) result.subscriptionData = subscriptionData;
    if (deviceID != null) result.deviceID = deviceID;
    if (unpassRegistered != null) result.unpassRegistered = unpassRegistered;
    if (lastExpiredOn != null) result.lastExpiredOn = lastExpiredOn;
    return result;
  }

  UserResponse_UserData._();

  factory UserResponse_UserData.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UserResponse_UserData.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UserResponse.UserData',
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'userId', protoName: 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'code')
    ..aOS(3, _omitFieldNames ? '' : 'token')
    ..aOS(4, _omitFieldNames ? '' : 'referral')
    ..aOS(5, _omitFieldNames ? '' : 'phone')
    ..aOS(6, _omitFieldNames ? '' : 'email')
    ..aOS(7, _omitFieldNames ? '' : 'userStatus', protoName: 'userStatus')
    ..aOS(8, _omitFieldNames ? '' : 'userLevel', protoName: 'userLevel')
    ..aOS(9, _omitFieldNames ? '' : 'locale')
    ..aInt64(10, _omitFieldNames ? '' : 'expiration')
    ..pPS(11, _omitFieldNames ? '' : 'servers')
    ..aOS(12, _omitFieldNames ? '' : 'subscription')
    ..pPS(13, _omitFieldNames ? '' : 'purchases')
    ..aOS(14, _omitFieldNames ? '' : 'bonusDays', protoName: 'bonusDays')
    ..aOS(15, _omitFieldNames ? '' : 'bonusMonths', protoName: 'bonusMonths')
    ..pPS(16, _omitFieldNames ? '' : 'inviters')
    ..pPS(17, _omitFieldNames ? '' : 'invitees')
    ..pPM<UserResponse_Device>(18, _omitFieldNames ? '' : 'devices',
        subBuilder: UserResponse_Device.create)
    ..aOB(19, _omitFieldNames ? '' : 'yinbiEnabled', protoName: 'yinbiEnabled')
    ..aOM<UserResponse_UserData_SubscriptionData>(
        20, _omitFieldNames ? '' : 'subscriptionData',
        protoName: 'subscriptionData',
        subBuilder: UserResponse_UserData_SubscriptionData.create)
    ..aOS(21, _omitFieldNames ? '' : 'deviceID', protoName: 'deviceID')
    ..aOB(22, _omitFieldNames ? '' : 'unpassRegistered',
        protoName: 'unpassRegistered')
    ..aInt64(23, _omitFieldNames ? '' : 'lastExpiredOn',
        protoName: 'lastExpiredOn')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserResponse_UserData clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserResponse_UserData copyWith(
          void Function(UserResponse_UserData) updates) =>
      super.copyWith((message) => updates(message as UserResponse_UserData))
          as UserResponse_UserData;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UserResponse_UserData create() => UserResponse_UserData._();
  @$core.override
  UserResponse_UserData createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UserResponse_UserData getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UserResponse_UserData>(create);
  static UserResponse_UserData? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get userId => $_getI64(0);
  @$pb.TagNumber(1)
  set userId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get code => $_getSZ(1);
  @$pb.TagNumber(2)
  set code($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCode() => $_has(1);
  @$pb.TagNumber(2)
  void clearCode() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get token => $_getSZ(2);
  @$pb.TagNumber(3)
  set token($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasToken() => $_has(2);
  @$pb.TagNumber(3)
  void clearToken() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get referral => $_getSZ(3);
  @$pb.TagNumber(4)
  set referral($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasReferral() => $_has(3);
  @$pb.TagNumber(4)
  void clearReferral() => $_clearField(4);

  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(5)
  $core.String get phone => $_getSZ(4);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(5)
  set phone($core.String value) => $_setString(4, value);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(5)
  $core.bool hasPhone() => $_has(4);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(5)
  void clearPhone() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get email => $_getSZ(5);
  @$pb.TagNumber(6)
  set email($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasEmail() => $_has(5);
  @$pb.TagNumber(6)
  void clearEmail() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get userStatus => $_getSZ(6);
  @$pb.TagNumber(7)
  set userStatus($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasUserStatus() => $_has(6);
  @$pb.TagNumber(7)
  void clearUserStatus() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get userLevel => $_getSZ(7);
  @$pb.TagNumber(8)
  set userLevel($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasUserLevel() => $_has(7);
  @$pb.TagNumber(8)
  void clearUserLevel() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get locale => $_getSZ(8);
  @$pb.TagNumber(9)
  set locale($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasLocale() => $_has(8);
  @$pb.TagNumber(9)
  void clearLocale() => $_clearField(9);

  @$pb.TagNumber(10)
  $fixnum.Int64 get expiration => $_getI64(9);
  @$pb.TagNumber(10)
  set expiration($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(10)
  $core.bool hasExpiration() => $_has(9);
  @$pb.TagNumber(10)
  void clearExpiration() => $_clearField(10);

  @$pb.TagNumber(11)
  $pb.PbList<$core.String> get servers => $_getList(10);

  @$pb.TagNumber(12)
  $core.String get subscription => $_getSZ(11);
  @$pb.TagNumber(12)
  set subscription($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasSubscription() => $_has(11);
  @$pb.TagNumber(12)
  void clearSubscription() => $_clearField(12);

  @$pb.TagNumber(13)
  $pb.PbList<$core.String> get purchases => $_getList(12);

  @$pb.TagNumber(14)
  $core.String get bonusDays => $_getSZ(13);
  @$pb.TagNumber(14)
  set bonusDays($core.String value) => $_setString(13, value);
  @$pb.TagNumber(14)
  $core.bool hasBonusDays() => $_has(13);
  @$pb.TagNumber(14)
  void clearBonusDays() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.String get bonusMonths => $_getSZ(14);
  @$pb.TagNumber(15)
  set bonusMonths($core.String value) => $_setString(14, value);
  @$pb.TagNumber(15)
  $core.bool hasBonusMonths() => $_has(14);
  @$pb.TagNumber(15)
  void clearBonusMonths() => $_clearField(15);

  @$pb.TagNumber(16)
  $pb.PbList<$core.String> get inviters => $_getList(15);

  @$pb.TagNumber(17)
  $pb.PbList<$core.String> get invitees => $_getList(16);

  @$pb.TagNumber(18)
  $pb.PbList<UserResponse_Device> get devices => $_getList(17);

  @$pb.TagNumber(19)
  $core.bool get yinbiEnabled => $_getBF(18);
  @$pb.TagNumber(19)
  set yinbiEnabled($core.bool value) => $_setBool(18, value);
  @$pb.TagNumber(19)
  $core.bool hasYinbiEnabled() => $_has(18);
  @$pb.TagNumber(19)
  void clearYinbiEnabled() => $_clearField(19);

  @$pb.TagNumber(20)
  UserResponse_UserData_SubscriptionData get subscriptionData => $_getN(19);
  @$pb.TagNumber(20)
  set subscriptionData(UserResponse_UserData_SubscriptionData value) =>
      $_setField(20, value);
  @$pb.TagNumber(20)
  $core.bool hasSubscriptionData() => $_has(19);
  @$pb.TagNumber(20)
  void clearSubscriptionData() => $_clearField(20);
  @$pb.TagNumber(20)
  UserResponse_UserData_SubscriptionData ensureSubscriptionData() =>
      $_ensure(19);

  @$pb.TagNumber(21)
  $core.String get deviceID => $_getSZ(20);
  @$pb.TagNumber(21)
  set deviceID($core.String value) => $_setString(20, value);
  @$pb.TagNumber(21)
  $core.bool hasDeviceID() => $_has(20);
  @$pb.TagNumber(21)
  void clearDeviceID() => $_clearField(21);

  /// informs us whether the legacy id and token are username-password flow registered
  @$pb.TagNumber(22)
  $core.bool get unpassRegistered => $_getBF(21);
  @$pb.TagNumber(22)
  set unpassRegistered($core.bool value) => $_setBool(21, value);
  @$pb.TagNumber(22)
  $core.bool hasUnpassRegistered() => $_has(21);
  @$pb.TagNumber(22)
  void clearUnpassRegistered() => $_clearField(22);

  @$pb.TagNumber(23)
  $fixnum.Int64 get lastExpiredOn => $_getI64(22);
  @$pb.TagNumber(23)
  set lastExpiredOn($fixnum.Int64 value) => $_setInt64(22, value);
  @$pb.TagNumber(23)
  $core.bool hasLastExpiredOn() => $_has(22);
  @$pb.TagNumber(23)
  void clearLastExpiredOn() => $_clearField(23);
}

class UserResponse extends $pb.GeneratedMessage {
  factory UserResponse({
    $fixnum.Int64? legacyID,
    $core.String? legacyToken,
    $core.String? id,
    $core.bool? emailConfirmed,
    $core.bool? success,
    UserResponse_UserData? legacyUserData,
    $core.Iterable<UserResponse_Device>? devices,
  }) {
    final result = create();
    if (legacyID != null) result.legacyID = legacyID;
    if (legacyToken != null) result.legacyToken = legacyToken;
    if (id != null) result.id = id;
    if (emailConfirmed != null) result.emailConfirmed = emailConfirmed;
    if (success != null) result.success = success;
    if (legacyUserData != null) result.legacyUserData = legacyUserData;
    if (devices != null) result.devices.addAll(devices);
    return result;
  }

  UserResponse._();

  factory UserResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UserResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UserResponse',
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'legacyID', protoName: 'legacyID')
    ..aOS(2, _omitFieldNames ? '' : 'legacyToken', protoName: 'legacyToken')
    ..aOS(3, _omitFieldNames ? '' : 'id')
    ..aOB(4, _omitFieldNames ? '' : 'emailConfirmed',
        protoName: 'emailConfirmed')
    ..aOB(5, _omitFieldNames ? '' : 'Success', protoName: 'Success')
    ..aOM<UserResponse_UserData>(6, _omitFieldNames ? '' : 'legacyUserData',
        protoName: 'legacyUserData', subBuilder: UserResponse_UserData.create)
    ..pPM<UserResponse_Device>(7, _omitFieldNames ? '' : 'devices',
        subBuilder: UserResponse_Device.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserResponse copyWith(void Function(UserResponse) updates) =>
      super.copyWith((message) => updates(message as UserResponse))
          as UserResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UserResponse create() => UserResponse._();
  @$core.override
  UserResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UserResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UserResponse>(create);
  static UserResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get legacyID => $_getI64(0);
  @$pb.TagNumber(1)
  set legacyID($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLegacyID() => $_has(0);
  @$pb.TagNumber(1)
  void clearLegacyID() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get legacyToken => $_getSZ(1);
  @$pb.TagNumber(2)
  set legacyToken($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLegacyToken() => $_has(1);
  @$pb.TagNumber(2)
  void clearLegacyToken() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get id => $_getSZ(2);
  @$pb.TagNumber(3)
  set id($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasId() => $_has(2);
  @$pb.TagNumber(3)
  void clearId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get emailConfirmed => $_getBF(3);
  @$pb.TagNumber(4)
  set emailConfirmed($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEmailConfirmed() => $_has(3);
  @$pb.TagNumber(4)
  void clearEmailConfirmed() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get success => $_getBF(4);
  @$pb.TagNumber(5)
  set success($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSuccess() => $_has(4);
  @$pb.TagNumber(5)
  void clearSuccess() => $_clearField(5);

  /// this maps to /user-data call in pro-server and is returned only on successful login
  @$pb.TagNumber(6)
  UserResponse_UserData get legacyUserData => $_getN(5);
  @$pb.TagNumber(6)
  set legacyUserData(UserResponse_UserData value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasLegacyUserData() => $_has(5);
  @$pb.TagNumber(6)
  void clearLegacyUserData() => $_clearField(6);
  @$pb.TagNumber(6)
  UserResponse_UserData ensureLegacyUserData() => $_ensure(5);

  /// list of current user devices. returned only on successful login that is blocked by 'too many devices'
  @$pb.TagNumber(7)
  $pb.PbList<UserResponse_Device> get devices => $_getList(6);
}

class Purchase extends $pb.GeneratedMessage {
  factory Purchase({
    $core.String? plan,
  }) {
    final result = create();
    if (plan != null) result.plan = plan;
    return result;
  }

  Purchase._();

  factory Purchase.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Purchase.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Purchase',
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'plan')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Purchase clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Purchase copyWith(void Function(Purchase) updates) =>
      super.copyWith((message) => updates(message as Purchase)) as Purchase;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Purchase create() => Purchase._();
  @$core.override
  Purchase createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Purchase getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Purchase>(create);
  static Purchase? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get plan => $_getSZ(0);
  @$pb.TagNumber(1)
  set plan($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPlan() => $_has(0);
  @$pb.TagNumber(1)
  void clearPlan() => $_clearField(1);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
