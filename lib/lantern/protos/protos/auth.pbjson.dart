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

@$core.Deprecated('Use userResponseDescriptor instead')
const UserResponse$json = {
  '1': 'UserResponse',
  '2': [
    {'1': 'legacyID', '3': 1, '4': 1, '5': 3, '10': 'legacyID'},
    {'1': 'legacyToken', '3': 2, '4': 1, '5': 9, '10': 'legacyToken'},
    {'1': 'id', '3': 3, '4': 1, '5': 9, '10': 'id'},
    {'1': 'emailConfirmed', '3': 4, '4': 1, '5': 8, '10': 'emailConfirmed'},
    {'1': 'Success', '3': 5, '4': 1, '5': 8, '10': 'Success'},
    {'1': 'legacyUserData', '3': 6, '4': 1, '5': 11, '6': '.UserResponse.UserData', '10': 'legacyUserData'},
    {'1': 'devices', '3': 7, '4': 3, '5': 11, '6': '.UserResponse.Device', '10': 'devices'},
  ],
  '3': [UserResponse_Device$json, UserResponse_UserData$json],
};

@$core.Deprecated('Use userResponseDescriptor instead')
const UserResponse_Device$json = {
  '1': 'Device',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'created', '3': 3, '4': 1, '5': 3, '10': 'created'},
  ],
};

@$core.Deprecated('Use userResponseDescriptor instead')
const UserResponse_UserData$json = {
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
    {'1': 'purchases', '3': 13, '4': 3, '5': 9, '10': 'purchases'},
    {'1': 'bonusDays', '3': 14, '4': 1, '5': 9, '10': 'bonusDays'},
    {'1': 'bonusMonths', '3': 15, '4': 1, '5': 9, '10': 'bonusMonths'},
    {'1': 'inviters', '3': 16, '4': 3, '5': 9, '10': 'inviters'},
    {'1': 'invitees', '3': 17, '4': 3, '5': 9, '10': 'invitees'},
    {'1': 'devices', '3': 18, '4': 3, '5': 11, '6': '.UserResponse.Device', '10': 'devices'},
    {'1': 'yinbiEnabled', '3': 19, '4': 1, '5': 8, '10': 'yinbiEnabled'},
    {'1': 'subscriptionData', '3': 20, '4': 1, '5': 11, '6': '.UserResponse.UserData.SubscriptionData', '10': 'subscriptionData'},
  ],
  '3': [UserResponse_UserData_SubscriptionData$json],
};

@$core.Deprecated('Use userResponseDescriptor instead')
const UserResponse_UserData_SubscriptionData$json = {
  '1': 'SubscriptionData',
  '2': [
    {'1': 'planID', '3': 1, '4': 1, '5': 9, '10': 'planID'},
    {'1': 'stripeCustomerID', '3': 2, '4': 1, '5': 9, '10': 'stripeCustomerID'},
    {'1': 'startAt', '3': 3, '4': 1, '5': 9, '10': 'startAt'},
    {'1': 'cancelledAt', '3': 4, '4': 1, '5': 9, '10': 'cancelledAt'},
    {'1': 'autoRenew', '3': 5, '4': 1, '5': 8, '10': 'autoRenew'},
    {'1': 'subscriptionID', '3': 6, '4': 1, '5': 9, '10': 'subscriptionID'},
    {'1': 'status', '3': 7, '4': 1, '5': 9, '10': 'status'},
    {'1': 'provider', '3': 8, '4': 1, '5': 9, '10': 'provider'},
    {'1': 'createdAt', '3': 9, '4': 1, '5': 9, '10': 'createdAt'},
    {'1': 'endAt', '3': 10, '4': 1, '5': 9, '10': 'endAt'},
  ],
};

/// Descriptor for `UserResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userResponseDescriptor = $convert.base64Decode(
    'CgxVc2VyUmVzcG9uc2USGgoIbGVnYWN5SUQYASABKANSCGxlZ2FjeUlEEiAKC2xlZ2FjeVRva2'
    'VuGAIgASgJUgtsZWdhY3lUb2tlbhIOCgJpZBgDIAEoCVICaWQSJgoOZW1haWxDb25maXJtZWQY'
    'BCABKAhSDmVtYWlsQ29uZmlybWVkEhgKB1N1Y2Nlc3MYBSABKAhSB1N1Y2Nlc3MSPgoObGVnYW'
    'N5VXNlckRhdGEYBiABKAsyFi5Vc2VyUmVzcG9uc2UuVXNlckRhdGFSDmxlZ2FjeVVzZXJEYXRh'
    'Ei4KB2RldmljZXMYByADKAsyFC5Vc2VyUmVzcG9uc2UuRGV2aWNlUgdkZXZpY2VzGkYKBkRldm'
    'ljZRIOCgJpZBgBIAEoCVICaWQSEgoEbmFtZRgCIAEoCVIEbmFtZRIYCgdjcmVhdGVkGAMgASgD'
    'UgdjcmVhdGVkGsoHCghVc2VyRGF0YRIWCgZ1c2VySWQYASABKANSBnVzZXJJZBISCgRjb2RlGA'
    'IgASgJUgRjb2RlEhQKBXRva2VuGAMgASgJUgV0b2tlbhIaCghyZWZlcnJhbBgEIAEoCVIIcmVm'
    'ZXJyYWwSFAoFcGhvbmUYBSABKAlSBXBob25lEhQKBWVtYWlsGAYgASgJUgVlbWFpbBIeCgp1c2'
    'VyU3RhdHVzGAcgASgJUgp1c2VyU3RhdHVzEhwKCXVzZXJMZXZlbBgIIAEoCVIJdXNlckxldmVs'
    'EhYKBmxvY2FsZRgJIAEoCVIGbG9jYWxlEh4KCmV4cGlyYXRpb24YCiABKANSCmV4cGlyYXRpb2'
    '4SGAoHc2VydmVycxgLIAMoCVIHc2VydmVycxIiCgxzdWJzY3JpcHRpb24YDCABKAlSDHN1YnNj'
    'cmlwdGlvbhIcCglwdXJjaGFzZXMYDSADKAlSCXB1cmNoYXNlcxIcCglib251c0RheXMYDiABKA'
    'lSCWJvbnVzRGF5cxIgCgtib251c01vbnRocxgPIAEoCVILYm9udXNNb250aHMSGgoIaW52aXRl'
    'cnMYECADKAlSCGludml0ZXJzEhoKCGludml0ZWVzGBEgAygJUghpbnZpdGVlcxIuCgdkZXZpY2'
    'VzGBIgAygLMhQuVXNlclJlc3BvbnNlLkRldmljZVIHZGV2aWNlcxIiCgx5aW5iaUVuYWJsZWQY'
    'EyABKAhSDHlpbmJpRW5hYmxlZBJTChBzdWJzY3JpcHRpb25EYXRhGBQgASgLMicuVXNlclJlc3'
    'BvbnNlLlVzZXJEYXRhLlN1YnNjcmlwdGlvbkRhdGFSEHN1YnNjcmlwdGlvbkRhdGEawAIKEFN1'
    'YnNjcmlwdGlvbkRhdGESFgoGcGxhbklEGAEgASgJUgZwbGFuSUQSKgoQc3RyaXBlQ3VzdG9tZX'
    'JJRBgCIAEoCVIQc3RyaXBlQ3VzdG9tZXJJRBIYCgdzdGFydEF0GAMgASgJUgdzdGFydEF0EiAK'
    'C2NhbmNlbGxlZEF0GAQgASgJUgtjYW5jZWxsZWRBdBIcCglhdXRvUmVuZXcYBSABKAhSCWF1dG'
    '9SZW5ldxImCg5zdWJzY3JpcHRpb25JRBgGIAEoCVIOc3Vic2NyaXB0aW9uSUQSFgoGc3RhdHVz'
    'GAcgASgJUgZzdGF0dXMSGgoIcHJvdmlkZXIYCCABKAlSCHByb3ZpZGVyEhwKCWNyZWF0ZWRBdB'
    'gJIAEoCVIJY3JlYXRlZEF0EhQKBWVuZEF0GAogASgJUgVlbmRBdA==');

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

