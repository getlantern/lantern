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
    {'1': 'subscriptionData', '3': 20, '4': 1, '5': 11, '6': '.UserResponse.SubscriptionData', '10': 'subscriptionData'},
  ],
  '3': [UserResponse_Device$json, UserResponse_UserData$json, UserResponse_SubscriptionData$json],
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
    {'1': 'purchases', '3': 13, '4': 3, '5': 11, '6': '.Purchase', '10': 'purchases'},
    {'1': 'bonusDays', '3': 14, '4': 1, '5': 9, '10': 'bonusDays'},
    {'1': 'bonusMonths', '3': 15, '4': 1, '5': 9, '10': 'bonusMonths'},
    {'1': 'inviters', '3': 16, '4': 3, '5': 9, '10': 'inviters'},
    {'1': 'invitees', '3': 17, '4': 3, '5': 9, '10': 'invitees'},
    {'1': 'devices', '3': 18, '4': 3, '5': 11, '6': '.UserResponse.Device', '10': 'devices'},
    {'1': 'yinbiEnabled', '3': 19, '4': 1, '5': 8, '10': 'yinbiEnabled'},
  ],
};

@$core.Deprecated('Use userResponseDescriptor instead')
const UserResponse_SubscriptionData$json = {
  '1': 'SubscriptionData',
  '2': [
    {'1': 'subscription_i_d', '3': 1, '4': 1, '5': 9, '10': 'subscriptionID'},
    {'1': 'plan_i_d', '3': 2, '4': 1, '5': 9, '10': 'planID'},
    {'1': 'stripe_customer_i_d', '3': 3, '4': 1, '5': 9, '10': 'stripeCustomerID'},
    {'1': 'status', '3': 4, '4': 1, '5': 9, '10': 'status'},
    {'1': 'provider', '3': 5, '4': 1, '5': 9, '10': 'provider'},
    {'1': 'created_at', '3': 6, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'createdAt'},
    {'1': 'start_at', '3': 7, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'startAt'},
    {'1': 'end_at', '3': 8, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'endAt'},
    {'1': 'cancelled_at', '3': 9, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'cancelledAt'},
    {'1': 'auto_renew', '3': 10, '4': 1, '5': 8, '10': 'autoRenew'},
  ],
};

/// Descriptor for `UserResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userResponseDescriptor = $convert.base64Decode(
    'CgxVc2VyUmVzcG9uc2USGgoIbGVnYWN5SUQYASABKANSCGxlZ2FjeUlEEiAKC2xlZ2FjeVRva2'
    'VuGAIgASgJUgtsZWdhY3lUb2tlbhIOCgJpZBgDIAEoCVICaWQSJgoOZW1haWxDb25maXJtZWQY'
    'BCABKAhSDmVtYWlsQ29uZmlybWVkEhgKB1N1Y2Nlc3MYBSABKAhSB1N1Y2Nlc3MSPgoObGVnYW'
    'N5VXNlckRhdGEYBiABKAsyFi5Vc2VyUmVzcG9uc2UuVXNlckRhdGFSDmxlZ2FjeVVzZXJEYXRh'
    'Ei4KB2RldmljZXMYByADKAsyFC5Vc2VyUmVzcG9uc2UuRGV2aWNlUgdkZXZpY2VzEkoKEHN1Yn'
    'NjcmlwdGlvbkRhdGEYFCABKAsyHi5Vc2VyUmVzcG9uc2UuU3Vic2NyaXB0aW9uRGF0YVIQc3Vi'
    'c2NyaXB0aW9uRGF0YRpGCgZEZXZpY2USDgoCaWQYASABKAlSAmlkEhIKBG5hbWUYAiABKAlSBG'
    '5hbWUSGAoHY3JlYXRlZBgDIAEoA1IHY3JlYXRlZBq9BAoIVXNlckRhdGESFgoGdXNlcklkGAEg'
    'ASgDUgZ1c2VySWQSEgoEY29kZRgCIAEoCVIEY29kZRIUCgV0b2tlbhgDIAEoCVIFdG9rZW4SGg'
    'oIcmVmZXJyYWwYBCABKAlSCHJlZmVycmFsEhQKBXBob25lGAUgASgJUgVwaG9uZRIUCgVlbWFp'
    'bBgGIAEoCVIFZW1haWwSHgoKdXNlclN0YXR1cxgHIAEoCVIKdXNlclN0YXR1cxIcCgl1c2VyTG'
    'V2ZWwYCCABKAlSCXVzZXJMZXZlbBIWCgZsb2NhbGUYCSABKAlSBmxvY2FsZRIeCgpleHBpcmF0'
    'aW9uGAogASgDUgpleHBpcmF0aW9uEhgKB3NlcnZlcnMYCyADKAlSB3NlcnZlcnMSIgoMc3Vic2'
    'NyaXB0aW9uGAwgASgJUgxzdWJzY3JpcHRpb24SJwoJcHVyY2hhc2VzGA0gAygLMgkuUHVyY2hh'
    'c2VSCXB1cmNoYXNlcxIcCglib251c0RheXMYDiABKAlSCWJvbnVzRGF5cxIgCgtib251c01vbn'
    'RocxgPIAEoCVILYm9udXNNb250aHMSGgoIaW52aXRlcnMYECADKAlSCGludml0ZXJzEhoKCGlu'
    'dml0ZWVzGBEgAygJUghpbnZpdGVlcxIuCgdkZXZpY2VzGBIgAygLMhQuVXNlclJlc3BvbnNlLk'
    'RldmljZVIHZGV2aWNlcxIiCgx5aW5iaUVuYWJsZWQYEyABKAhSDHlpbmJpRW5hYmxlZBq8AwoQ'
    'U3Vic2NyaXB0aW9uRGF0YRIoChBzdWJzY3JpcHRpb25faV9kGAEgASgJUg5zdWJzY3JpcHRpb2'
    '5JRBIYCghwbGFuX2lfZBgCIAEoCVIGcGxhbklEEi0KE3N0cmlwZV9jdXN0b21lcl9pX2QYAyAB'
    'KAlSEHN0cmlwZUN1c3RvbWVySUQSFgoGc3RhdHVzGAQgASgJUgZzdGF0dXMSGgoIcHJvdmlkZX'
    'IYBSABKAlSCHByb3ZpZGVyEjkKCmNyZWF0ZWRfYXQYBiABKAsyGi5nb29nbGUucHJvdG9idWYu'
    'VGltZXN0YW1wUgljcmVhdGVkQXQSNQoIc3RhcnRfYXQYByABKAsyGi5nb29nbGUucHJvdG9idW'
    'YuVGltZXN0YW1wUgdzdGFydEF0EjEKBmVuZF9hdBgIIAEoCzIaLmdvb2dsZS5wcm90b2J1Zi5U'
    'aW1lc3RhbXBSBWVuZEF0Ej0KDGNhbmNlbGxlZF9hdBgJIAEoCzIaLmdvb2dsZS5wcm90b2J1Zi'
    '5UaW1lc3RhbXBSC2NhbmNlbGxlZEF0Eh0KCmF1dG9fcmVuZXcYCiABKAhSCWF1dG9SZW5ldw==');

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

