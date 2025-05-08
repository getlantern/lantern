//
//  Generated code. Do not modify.
//  source: protos/auth.proto
//
// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class LoginResponse_Device extends $pb.GeneratedMessage {
  factory LoginResponse_Device({
    $core.String? id,
    $core.String? name,
    $fixnum.Int64? created,
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    if (name != null) {
      $result.name = name;
    }
    if (created != null) {
      $result.created = created;
    }
    return $result;
  }
  LoginResponse_Device._() : super();
  factory LoginResponse_Device.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory LoginResponse_Device.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'LoginResponse.Device', createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aInt64(3, _omitFieldNames ? '' : 'created')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  LoginResponse_Device clone() => LoginResponse_Device()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  LoginResponse_Device copyWith(void Function(LoginResponse_Device) updates) => super.copyWith((message) => updates(message as LoginResponse_Device)) as LoginResponse_Device;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LoginResponse_Device create() => LoginResponse_Device._();
  LoginResponse_Device createEmptyInstance() => create();
  static $pb.PbList<LoginResponse_Device> createRepeated() => $pb.PbList<LoginResponse_Device>();
  @$core.pragma('dart2js:noInline')
  static LoginResponse_Device getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LoginResponse_Device>(create);
  static LoginResponse_Device? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get created => $_getI64(2);
  @$pb.TagNumber(3)
  set created($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasCreated() => $_has(2);
  @$pb.TagNumber(3)
  void clearCreated() => $_clearField(3);
}

class LoginResponse_UserData extends $pb.GeneratedMessage {
  factory LoginResponse_UserData({
    $fixnum.Int64? userId,
    $core.String? code,
    $core.String? token,
    $core.String? referral,
    $core.String? phone,
    $core.String? email,
    $core.String? userStatus,
    $core.String? userLevel,
    $core.String? locale,
    $fixnum.Int64? expiration,
    $core.Iterable<$core.String>? servers,
    $core.String? subscription,
    $core.Iterable<Purchase>? purchases,
    $core.String? bonusDays,
    $core.String? bonusMonths,
    $core.Iterable<$core.String>? inviters,
    $core.Iterable<$core.String>? invitees,
    $core.Iterable<LoginResponse_Device>? devices,
    $core.bool? yinbiEnabled,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (code != null) {
      $result.code = code;
    }
    if (token != null) {
      $result.token = token;
    }
    if (referral != null) {
      $result.referral = referral;
    }
    if (phone != null) {
      $result.phone = phone;
    }
    if (email != null) {
      $result.email = email;
    }
    if (userStatus != null) {
      $result.userStatus = userStatus;
    }
    if (userLevel != null) {
      $result.userLevel = userLevel;
    }
    if (locale != null) {
      $result.locale = locale;
    }
    if (expiration != null) {
      $result.expiration = expiration;
    }
    if (servers != null) {
      $result.servers.addAll(servers);
    }
    if (subscription != null) {
      $result.subscription = subscription;
    }
    if (purchases != null) {
      $result.purchases.addAll(purchases);
    }
    if (bonusDays != null) {
      $result.bonusDays = bonusDays;
    }
    if (bonusMonths != null) {
      $result.bonusMonths = bonusMonths;
    }
    if (inviters != null) {
      $result.inviters.addAll(inviters);
    }
    if (invitees != null) {
      $result.invitees.addAll(invitees);
    }
    if (devices != null) {
      $result.devices.addAll(devices);
    }
    if (yinbiEnabled != null) {
      $result.yinbiEnabled = yinbiEnabled;
    }
    return $result;
  }
  LoginResponse_UserData._() : super();
  factory LoginResponse_UserData.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory LoginResponse_UserData.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'LoginResponse.UserData', createEmptyInstance: create)
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
    ..pc<Purchase>(13, _omitFieldNames ? '' : 'purchases', $pb.PbFieldType.PM, subBuilder: Purchase.create)
    ..aOS(14, _omitFieldNames ? '' : 'bonusDays', protoName: 'bonusDays')
    ..aOS(15, _omitFieldNames ? '' : 'bonusMonths', protoName: 'bonusMonths')
    ..pPS(16, _omitFieldNames ? '' : 'inviters')
    ..pPS(17, _omitFieldNames ? '' : 'invitees')
    ..pc<LoginResponse_Device>(18, _omitFieldNames ? '' : 'devices', $pb.PbFieldType.PM, subBuilder: LoginResponse_Device.create)
    ..aOB(19, _omitFieldNames ? '' : 'yinbiEnabled', protoName: 'yinbiEnabled')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  LoginResponse_UserData clone() => LoginResponse_UserData()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  LoginResponse_UserData copyWith(void Function(LoginResponse_UserData) updates) => super.copyWith((message) => updates(message as LoginResponse_UserData)) as LoginResponse_UserData;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LoginResponse_UserData create() => LoginResponse_UserData._();
  LoginResponse_UserData createEmptyInstance() => create();
  static $pb.PbList<LoginResponse_UserData> createRepeated() => $pb.PbList<LoginResponse_UserData>();
  @$core.pragma('dart2js:noInline')
  static LoginResponse_UserData getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LoginResponse_UserData>(create);
  static LoginResponse_UserData? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get userId => $_getI64(0);
  @$pb.TagNumber(1)
  set userId($fixnum.Int64 v) { $_setInt64(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get code => $_getSZ(1);
  @$pb.TagNumber(2)
  set code($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasCode() => $_has(1);
  @$pb.TagNumber(2)
  void clearCode() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get token => $_getSZ(2);
  @$pb.TagNumber(3)
  set token($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasToken() => $_has(2);
  @$pb.TagNumber(3)
  void clearToken() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get referral => $_getSZ(3);
  @$pb.TagNumber(4)
  set referral($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasReferral() => $_has(3);
  @$pb.TagNumber(4)
  void clearReferral() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get phone => $_getSZ(4);
  @$pb.TagNumber(5)
  set phone($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasPhone() => $_has(4);
  @$pb.TagNumber(5)
  void clearPhone() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get email => $_getSZ(5);
  @$pb.TagNumber(6)
  set email($core.String v) { $_setString(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasEmail() => $_has(5);
  @$pb.TagNumber(6)
  void clearEmail() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get userStatus => $_getSZ(6);
  @$pb.TagNumber(7)
  set userStatus($core.String v) { $_setString(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasUserStatus() => $_has(6);
  @$pb.TagNumber(7)
  void clearUserStatus() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get userLevel => $_getSZ(7);
  @$pb.TagNumber(8)
  set userLevel($core.String v) { $_setString(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasUserLevel() => $_has(7);
  @$pb.TagNumber(8)
  void clearUserLevel() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get locale => $_getSZ(8);
  @$pb.TagNumber(9)
  set locale($core.String v) { $_setString(8, v); }
  @$pb.TagNumber(9)
  $core.bool hasLocale() => $_has(8);
  @$pb.TagNumber(9)
  void clearLocale() => $_clearField(9);

  @$pb.TagNumber(10)
  $fixnum.Int64 get expiration => $_getI64(9);
  @$pb.TagNumber(10)
  set expiration($fixnum.Int64 v) { $_setInt64(9, v); }
  @$pb.TagNumber(10)
  $core.bool hasExpiration() => $_has(9);
  @$pb.TagNumber(10)
  void clearExpiration() => $_clearField(10);

  @$pb.TagNumber(11)
  $pb.PbList<$core.String> get servers => $_getList(10);

  @$pb.TagNumber(12)
  $core.String get subscription => $_getSZ(11);
  @$pb.TagNumber(12)
  set subscription($core.String v) { $_setString(11, v); }
  @$pb.TagNumber(12)
  $core.bool hasSubscription() => $_has(11);
  @$pb.TagNumber(12)
  void clearSubscription() => $_clearField(12);

  @$pb.TagNumber(13)
  $pb.PbList<Purchase> get purchases => $_getList(12);

  @$pb.TagNumber(14)
  $core.String get bonusDays => $_getSZ(13);
  @$pb.TagNumber(14)
  set bonusDays($core.String v) { $_setString(13, v); }
  @$pb.TagNumber(14)
  $core.bool hasBonusDays() => $_has(13);
  @$pb.TagNumber(14)
  void clearBonusDays() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.String get bonusMonths => $_getSZ(14);
  @$pb.TagNumber(15)
  set bonusMonths($core.String v) { $_setString(14, v); }
  @$pb.TagNumber(15)
  $core.bool hasBonusMonths() => $_has(14);
  @$pb.TagNumber(15)
  void clearBonusMonths() => $_clearField(15);

  @$pb.TagNumber(16)
  $pb.PbList<$core.String> get inviters => $_getList(15);

  @$pb.TagNumber(17)
  $pb.PbList<$core.String> get invitees => $_getList(16);

  @$pb.TagNumber(18)
  $pb.PbList<LoginResponse_Device> get devices => $_getList(17);

  @$pb.TagNumber(19)
  $core.bool get yinbiEnabled => $_getBF(18);
  @$pb.TagNumber(19)
  set yinbiEnabled($core.bool v) { $_setBool(18, v); }
  @$pb.TagNumber(19)
  $core.bool hasYinbiEnabled() => $_has(18);
  @$pb.TagNumber(19)
  void clearYinbiEnabled() => $_clearField(19);
}

class LoginResponse extends $pb.GeneratedMessage {
  factory LoginResponse({
    $fixnum.Int64? legacyID,
    $core.String? legacyToken,
    $core.String? id,
    $core.bool? emailConfirmed,
    $core.bool? success,
    LoginResponse_UserData? legacyUserData,
    $core.Iterable<LoginResponse_Device>? devices,
  }) {
    final $result = create();
    if (legacyID != null) {
      $result.legacyID = legacyID;
    }
    if (legacyToken != null) {
      $result.legacyToken = legacyToken;
    }
    if (id != null) {
      $result.id = id;
    }
    if (emailConfirmed != null) {
      $result.emailConfirmed = emailConfirmed;
    }
    if (success != null) {
      $result.success = success;
    }
    if (legacyUserData != null) {
      $result.legacyUserData = legacyUserData;
    }
    if (devices != null) {
      $result.devices.addAll(devices);
    }
    return $result;
  }
  LoginResponse._() : super();
  factory LoginResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory LoginResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'LoginResponse', createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'legacyID', protoName: 'legacyID')
    ..aOS(2, _omitFieldNames ? '' : 'legacyToken', protoName: 'legacyToken')
    ..aOS(3, _omitFieldNames ? '' : 'id')
    ..aOB(4, _omitFieldNames ? '' : 'emailConfirmed', protoName: 'emailConfirmed')
    ..aOB(5, _omitFieldNames ? '' : 'Success', protoName: 'Success')
    ..aOM<LoginResponse_UserData>(6, _omitFieldNames ? '' : 'legacyUserData', protoName: 'legacyUserData', subBuilder: LoginResponse_UserData.create)
    ..pc<LoginResponse_Device>(7, _omitFieldNames ? '' : 'devices', $pb.PbFieldType.PM, subBuilder: LoginResponse_Device.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  LoginResponse clone() => LoginResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  LoginResponse copyWith(void Function(LoginResponse) updates) => super.copyWith((message) => updates(message as LoginResponse)) as LoginResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LoginResponse create() => LoginResponse._();
  LoginResponse createEmptyInstance() => create();
  static $pb.PbList<LoginResponse> createRepeated() => $pb.PbList<LoginResponse>();
  @$core.pragma('dart2js:noInline')
  static LoginResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LoginResponse>(create);
  static LoginResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get legacyID => $_getI64(0);
  @$pb.TagNumber(1)
  set legacyID($fixnum.Int64 v) { $_setInt64(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasLegacyID() => $_has(0);
  @$pb.TagNumber(1)
  void clearLegacyID() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get legacyToken => $_getSZ(1);
  @$pb.TagNumber(2)
  set legacyToken($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasLegacyToken() => $_has(1);
  @$pb.TagNumber(2)
  void clearLegacyToken() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get id => $_getSZ(2);
  @$pb.TagNumber(3)
  set id($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasId() => $_has(2);
  @$pb.TagNumber(3)
  void clearId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get emailConfirmed => $_getBF(3);
  @$pb.TagNumber(4)
  set emailConfirmed($core.bool v) { $_setBool(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasEmailConfirmed() => $_has(3);
  @$pb.TagNumber(4)
  void clearEmailConfirmed() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get success => $_getBF(4);
  @$pb.TagNumber(5)
  set success($core.bool v) { $_setBool(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasSuccess() => $_has(4);
  @$pb.TagNumber(5)
  void clearSuccess() => $_clearField(5);

  /// this maps to /user-data call in pro-server and is returned only on successful login
  @$pb.TagNumber(6)
  LoginResponse_UserData get legacyUserData => $_getN(5);
  @$pb.TagNumber(6)
  set legacyUserData(LoginResponse_UserData v) { $_setField(6, v); }
  @$pb.TagNumber(6)
  $core.bool hasLegacyUserData() => $_has(5);
  @$pb.TagNumber(6)
  void clearLegacyUserData() => $_clearField(6);
  @$pb.TagNumber(6)
  LoginResponse_UserData ensureLegacyUserData() => $_ensure(5);

  /// list of current user devices. returned only on successful login that is blocked by 'too many devices'
  @$pb.TagNumber(7)
  $pb.PbList<LoginResponse_Device> get devices => $_getList(6);
}

class Purchase extends $pb.GeneratedMessage {
  factory Purchase({
    $core.String? plan,
  }) {
    final $result = create();
    if (plan != null) {
      $result.plan = plan;
    }
    return $result;
  }
  Purchase._() : super();
  factory Purchase.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Purchase.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Purchase', createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'plan')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Purchase clone() => Purchase()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Purchase copyWith(void Function(Purchase) updates) => super.copyWith((message) => updates(message as Purchase)) as Purchase;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Purchase create() => Purchase._();
  Purchase createEmptyInstance() => create();
  static $pb.PbList<Purchase> createRepeated() => $pb.PbList<Purchase>();
  @$core.pragma('dart2js:noInline')
  static Purchase getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Purchase>(create);
  static Purchase? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get plan => $_getSZ(0);
  @$pb.TagNumber(1)
  set plan($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasPlan() => $_has(0);
  @$pb.TagNumber(1)
  void clearPlan() => $_clearField(1);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
