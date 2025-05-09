//
//  Generated code. Do not modify.
//  source: protos/auth.proto
//
// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use loginResponseDescriptor instead')
const LoginResponse$json = {
  '1': 'LoginResponse',
  '2': [
    {'1': 'legacyID', '3': 1, '4': 1, '5': 3, '10': 'legacyID'},
    {'1': 'legacyToken', '3': 2, '4': 1, '5': 9, '10': 'legacyToken'},
    {'1': 'id', '3': 3, '4': 1, '5': 9, '10': 'id'},
    {'1': 'emailConfirmed', '3': 4, '4': 1, '5': 8, '10': 'emailConfirmed'},
    {'1': 'Success', '3': 5, '4': 1, '5': 8, '10': 'Success'},
    {'1': 'legacyUserData', '3': 6, '4': 1, '5': 11, '6': '.LoginResponse.UserData', '10': 'legacyUserData'},
    {'1': 'devices', '3': 7, '4': 3, '5': 11, '6': '.LoginResponse.Device', '10': 'devices'},
  ],
  '3': [LoginResponse_Device$json, LoginResponse_UserData$json],
};

@$core.Deprecated('Use loginResponseDescriptor instead')
const LoginResponse_Device$json = {
  '1': 'Device',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'created', '3': 3, '4': 1, '5': 3, '10': 'created'},
  ],
};

@$core.Deprecated('Use loginResponseDescriptor instead')
const LoginResponse_UserData$json = {
  '1': 'UserData',
  '2': [
    {'1': 'userId', '3': 1, '4': 1, '5': 3, '10': 'userId'},
    {'1': 'code', '3': 2, '4': 1, '5': 9, '10': 'code'},
    {'1': 'token', '3': 3, '4': 1, '5': 9, '10': 'token'},
    {'1': 'referral', '3': 4, '4': 1, '5': 9, '10': 'referral'},
    {'1': 'phone', '3': 5, '4': 1, '5': 9, '10': 'phone'},
    {'1': 'email', '3': 6, '4': 1, '5': 9, '10': 'email'},
    {'1': 'userStatus', '3': 7, '4': 1, '5': 9, '10': 'userStatus'},
    {'1': 'userLevel', '3': 8, '4': 1, '5': 9, '10': 'userLevel'},
    {'1': 'locale', '3': 9, '4': 1, '5': 9, '10': 'locale'},
    {'1': 'expiration', '3': 10, '4': 1, '5': 3, '10': 'expiration'},
    {'1': 'servers', '3': 11, '4': 3, '5': 9, '10': 'servers'},
    {'1': 'subscription', '3': 12, '4': 1, '5': 9, '10': 'subscription'},
    {'1': 'purchases', '3': 13, '4': 3, '5': 11, '6': '.Purchase', '10': 'purchases'},
    {'1': 'bonusDays', '3': 14, '4': 1, '5': 9, '10': 'bonusDays'},
    {'1': 'bonusMonths', '3': 15, '4': 1, '5': 9, '10': 'bonusMonths'},
    {'1': 'inviters', '3': 16, '4': 3, '5': 9, '10': 'inviters'},
    {'1': 'invitees', '3': 17, '4': 3, '5': 9, '10': 'invitees'},
    {'1': 'devices', '3': 18, '4': 3, '5': 11, '6': '.LoginResponse.Device', '10': 'devices'},
    {'1': 'yinbiEnabled', '3': 19, '4': 1, '5': 8, '10': 'yinbiEnabled'},
  ],
};

/// Descriptor for `LoginResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List loginResponseDescriptor = $convert.base64Decode(
    'Cg1Mb2dpblJlc3BvbnNlEhoKCGxlZ2FjeUlEGAEgASgDUghsZWdhY3lJRBIgCgtsZWdhY3lUb2'
    'tlbhgCIAEoCVILbGVnYWN5VG9rZW4SDgoCaWQYAyABKAlSAmlkEiYKDmVtYWlsQ29uZmlybWVk'
    'GAQgASgIUg5lbWFpbENvbmZpcm1lZBIYCgdTdWNjZXNzGAUgASgIUgdTdWNjZXNzEj8KDmxlZ2'
    'FjeVVzZXJEYXRhGAYgASgLMhcuTG9naW5SZXNwb25zZS5Vc2VyRGF0YVIObGVnYWN5VXNlckRh'
    'dGESLwoHZGV2aWNlcxgHIAMoCzIVLkxvZ2luUmVzcG9uc2UuRGV2aWNlUgdkZXZpY2VzGkYKBk'
    'RldmljZRIOCgJpZBgBIAEoCVICaWQSEgoEbmFtZRgCIAEoCVIEbmFtZRIYCgdjcmVhdGVkGAMg'
    'ASgDUgdjcmVhdGVkGr4ECghVc2VyRGF0YRIWCgZ1c2VySWQYASABKANSBnVzZXJJZBISCgRjb2'
    'RlGAIgASgJUgRjb2RlEhQKBXRva2VuGAMgASgJUgV0b2tlbhIaCghyZWZlcnJhbBgEIAEoCVII'
    'cmVmZXJyYWwSFAoFcGhvbmUYBSABKAlSBXBob25lEhQKBWVtYWlsGAYgASgJUgVlbWFpbBIeCg'
    'p1c2VyU3RhdHVzGAcgASgJUgp1c2VyU3RhdHVzEhwKCXVzZXJMZXZlbBgIIAEoCVIJdXNlckxl'
    'dmVsEhYKBmxvY2FsZRgJIAEoCVIGbG9jYWxlEh4KCmV4cGlyYXRpb24YCiABKANSCmV4cGlyYX'
    'Rpb24SGAoHc2VydmVycxgLIAMoCVIHc2VydmVycxIiCgxzdWJzY3JpcHRpb24YDCABKAlSDHN1'
    'YnNjcmlwdGlvbhInCglwdXJjaGFzZXMYDSADKAsyCS5QdXJjaGFzZVIJcHVyY2hhc2VzEhwKCW'
    'JvbnVzRGF5cxgOIAEoCVIJYm9udXNEYXlzEiAKC2JvbnVzTW9udGhzGA8gASgJUgtib251c01v'
    'bnRocxIaCghpbnZpdGVycxgQIAMoCVIIaW52aXRlcnMSGgoIaW52aXRlZXMYESADKAlSCGludm'
    'l0ZWVzEi8KB2RldmljZXMYEiADKAsyFS5Mb2dpblJlc3BvbnNlLkRldmljZVIHZGV2aWNlcxIi'
    'Cgx5aW5iaUVuYWJsZWQYEyABKAhSDHlpbmJpRW5hYmxlZA==');

@$core.Deprecated('Use purchaseDescriptor instead')
const Purchase$json = {
  '1': 'Purchase',
  '2': [
    {'1': 'plan', '3': 1, '4': 1, '5': 9, '10': 'plan'},
  ],
};

/// Descriptor for `Purchase`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List purchaseDescriptor = $convert.base64Decode(
    'CghQdXJjaGFzZRISCgRwbGFuGAEgASgJUgRwbGFu');

