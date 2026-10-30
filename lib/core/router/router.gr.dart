// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:auto_route/auto_route.dart' as _i47;
import 'package:collection/collection.dart' as _i51;
import 'package:flutter/material.dart' as _i48;
import 'package:lantern/core/common/common.dart' as _i49;
import 'package:lantern/core/models/user.dart' as _i50;
import 'package:lantern/core/widgets/app_webview.dart' as _i4;
import 'package:lantern/features/account/account.dart' as _i1;
import 'package:lantern/features/account/delete_account.dart' as _i10;
import 'package:lantern/features/auth/add_email.dart' as _i3;
import 'package:lantern/features/auth/choose_payment_method.dart' as _i7;
import 'package:lantern/features/auth/confirm_email.dart' as _i8;
import 'package:lantern/features/auth/create_password.dart' as _i9;
import 'package:lantern/features/auth/device_limit_reached.dart' as _i12;
import 'package:lantern/features/auth/lantern_pro_license.dart' as _i21;
import 'package:lantern/features/auth/reset_password.dart' as _i35;
import 'package:lantern/features/auth/reset_password_email.dart' as _i36;
import 'package:lantern/features/auth/sign_in_email.dart' as _i39;
import 'package:lantern/features/auth/sign_in_password.dart' as _i40;
import 'package:lantern/features/developer/developer_mode.dart' as _i11;
import 'package:lantern/features/helpers/help_friend.dart' as _i15;
import 'package:lantern/features/helpers/invite_share.dart' as _i18;
import 'package:lantern/features/home/home.dart' as _i16;
import 'package:lantern/features/language/language.dart' as _i20;
import 'package:lantern/features/logs/logs.dart' as _i22;
import 'package:lantern/features/macos_extension/macos_extension_dialog.dart'
    as _i23;
import 'package:lantern/features/onboarding/onboarding.dart' as _i26;
import 'package:lantern/features/plans/plans.dart' as _i27;
import 'package:lantern/features/private_server/join_private_server.dart'
    as _i19;
import 'package:lantern/features/private_server/manage_private_server.dart'
    as _i24;
import 'package:lantern/features/private_server/manually_server_setup.dart'
    as _i25;
import 'package:lantern/features/private_server/private_server_add_billing.dart'
    as _i28;
import 'package:lantern/features/private_server/private_server_deploy.dart'
    as _i29;
import 'package:lantern/features/private_server/private_server_locations.dart'
    as _i30;
import 'package:lantern/features/private_server/private_server_setup.dart'
    as _i31;
import 'package:lantern/features/private_server/private_sever_details.dart'
    as _i32;
import 'package:lantern/features/qr_scanner/qr_code_scanner.dart' as _i33;
import 'package:lantern/features/report_issue/report_issue.dart' as _i34;
import 'package:lantern/features/setting/action_mode_setting.dart' as _i2;
import 'package:lantern/features/setting/appearance.dart' as _i5;
import 'package:lantern/features/setting/download_links.dart' as _i13;
import 'package:lantern/features/setting/follow_us.dart' as _i14;
import 'package:lantern/features/setting/invite_friends.dart' as _i17;
import 'package:lantern/features/setting/setting.dart' as _i38;
import 'package:lantern/features/setting/smart_routing.dart' as _i41;
import 'package:lantern/features/setting/vpn_setting.dart' as _i45;
import 'package:lantern/features/split_tunneling/apps_split_tunneling.dart'
    as _i6;
import 'package:lantern/features/split_tunneling/split_tunneling.dart' as _i42;
import 'package:lantern/features/split_tunneling/split_tunneling_info.dart'
    as _i43;
import 'package:lantern/features/split_tunneling/website_split_tunneling.dart'
    as _i46;
import 'package:lantern/features/support/support.dart' as _i44;
import 'package:lantern/features/vpn/server_selection.dart' as _i37;

/// generated route for
/// [_i1.Account]
class Account extends _i47.PageRouteInfo<void> {
  const Account({List<_i47.PageRouteInfo>? children})
    : super(Account.name, initialChildren: children);

  static const String name = 'Account';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      return const _i1.Account();
    },
  );
}

/// generated route for
/// [_i2.ActionModeSetting]
class ActionModeSetting extends _i47.PageRouteInfo<void> {
  const ActionModeSetting({List<_i47.PageRouteInfo>? children})
    : super(ActionModeSetting.name, initialChildren: children);

  static const String name = 'ActionModeSetting';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      return const _i2.ActionModeSetting();
    },
  );
}

/// generated route for
/// [_i3.AddEmail]
class AddEmail extends _i47.PageRouteInfo<AddEmailArgs> {
  AddEmail({
    _i48.Key? key,
    _i49.AuthFlow authFlow = _i49.AuthFlow.signUp,
    String? password,
    String licenseKey = '',
    List<_i47.PageRouteInfo>? children,
  }) : super(
         AddEmail.name,
         args: AddEmailArgs(
           key: key,
           authFlow: authFlow,
           password: password,
           licenseKey: licenseKey,
         ),
         initialChildren: children,
       );

  static const String name = 'AddEmail';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<AddEmailArgs>(
        orElse: () => const AddEmailArgs(),
      );
      return _i3.AddEmail(
        key: args.key,
        authFlow: args.authFlow,
        password: args.password,
        licenseKey: args.licenseKey,
      );
    },
  );
}

class AddEmailArgs {
  const AddEmailArgs({
    this.key,
    this.authFlow = _i49.AuthFlow.signUp,
    this.password,
    this.licenseKey = '',
  });

  final _i48.Key? key;

  final _i49.AuthFlow authFlow;

  final String? password;

  final String licenseKey;

  @override
  String toString() {
    return 'AddEmailArgs{key: $key, authFlow: $authFlow, password: $password, licenseKey: $licenseKey}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AddEmailArgs) return false;
    return key == other.key &&
        authFlow == other.authFlow &&
        password == other.password &&
        licenseKey == other.licenseKey;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      authFlow.hashCode ^
      password.hashCode ^
      licenseKey.hashCode;
}

/// generated route for
/// [_i4.AppWebView]
class AppWebview extends _i47.PageRouteInfo<AppWebviewArgs> {
  AppWebview({
    _i48.Key? key,
    required String title,
    required String url,
    _i4.AppWebViewObserver? observer,
    List<_i47.PageRouteInfo>? children,
  }) : super(
         AppWebview.name,
         args: AppWebviewArgs(
           key: key,
           title: title,
           url: url,
           observer: observer,
         ),
         initialChildren: children,
       );

  static const String name = 'AppWebview';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<AppWebviewArgs>();
      return _i4.AppWebView(
        key: args.key,
        title: args.title,
        url: args.url,
        observer: args.observer,
      );
    },
  );
}

class AppWebviewArgs {
  const AppWebviewArgs({
    this.key,
    required this.title,
    required this.url,
    this.observer,
  });

  final _i48.Key? key;

  final String title;

  final String url;

  final _i4.AppWebViewObserver? observer;

  @override
  String toString() {
    return 'AppWebviewArgs{key: $key, title: $title, url: $url, observer: $observer}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AppWebviewArgs) return false;
    return key == other.key &&
        title == other.title &&
        url == other.url &&
        observer == other.observer;
  }

  @override
  int get hashCode =>
      key.hashCode ^ title.hashCode ^ url.hashCode ^ observer.hashCode;
}

/// generated route for
/// [_i5.Appearance]
class Appearance extends _i47.PageRouteInfo<void> {
  const Appearance({List<_i47.PageRouteInfo>? children})
    : super(Appearance.name, initialChildren: children);

  static const String name = 'Appearance';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      return const _i5.Appearance();
    },
  );
}

/// generated route for
/// [_i6.AppsSplitTunneling]
class AppsSplitTunneling extends _i47.PageRouteInfo<void> {
  const AppsSplitTunneling({List<_i47.PageRouteInfo>? children})
    : super(AppsSplitTunneling.name, initialChildren: children);

  static const String name = 'AppsSplitTunneling';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      return const _i6.AppsSplitTunneling();
    },
  );
}

/// generated route for
/// [_i7.ChoosePaymentMethod]
class ChoosePaymentMethod extends _i47.PageRouteInfo<ChoosePaymentMethodArgs> {
  ChoosePaymentMethod({
    _i48.Key? key,
    required String email,
    String? code,
    required _i49.AuthFlow authFlow,
    _i4.AppWebViewObserver? checkoutObserver,
    List<_i47.PageRouteInfo>? children,
  }) : super(
         ChoosePaymentMethod.name,
         args: ChoosePaymentMethodArgs(
           key: key,
           email: email,
           code: code,
           authFlow: authFlow,
           checkoutObserver: checkoutObserver,
         ),
         initialChildren: children,
       );

  static const String name = 'ChoosePaymentMethod';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ChoosePaymentMethodArgs>();
      return _i7.ChoosePaymentMethod(
        key: args.key,
        email: args.email,
        code: args.code,
        authFlow: args.authFlow,
        checkoutObserver: args.checkoutObserver,
      );
    },
  );
}

class ChoosePaymentMethodArgs {
  const ChoosePaymentMethodArgs({
    this.key,
    required this.email,
    this.code,
    required this.authFlow,
    this.checkoutObserver,
  });

  final _i48.Key? key;

  final String email;

  final String? code;

  final _i49.AuthFlow authFlow;

  final _i4.AppWebViewObserver? checkoutObserver;

  @override
  String toString() {
    return 'ChoosePaymentMethodArgs{key: $key, email: $email, code: $code, authFlow: $authFlow, checkoutObserver: $checkoutObserver}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ChoosePaymentMethodArgs) return false;
    return key == other.key &&
        email == other.email &&
        code == other.code &&
        authFlow == other.authFlow &&
        checkoutObserver == other.checkoutObserver;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      email.hashCode ^
      code.hashCode ^
      authFlow.hashCode ^
      checkoutObserver.hashCode;
}

/// generated route for
/// [_i8.ConfirmEmail]
class ConfirmEmail extends _i47.PageRouteInfo<ConfirmEmailArgs> {
  ConfirmEmail({
    _i48.Key? key,
    required String email,
    String? password,
    _i49.AuthFlow authFlow = _i49.AuthFlow.signUp,
    String licenseKey = '',
    List<_i47.PageRouteInfo>? children,
  }) : super(
         ConfirmEmail.name,
         args: ConfirmEmailArgs(
           key: key,
           email: email,
           password: password,
           authFlow: authFlow,
           licenseKey: licenseKey,
         ),
         initialChildren: children,
       );

  static const String name = 'ConfirmEmail';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ConfirmEmailArgs>();
      return _i8.ConfirmEmail(
        key: args.key,
        email: args.email,
        password: args.password,
        authFlow: args.authFlow,
        licenseKey: args.licenseKey,
      );
    },
  );
}

class ConfirmEmailArgs {
  const ConfirmEmailArgs({
    this.key,
    required this.email,
    this.password,
    this.authFlow = _i49.AuthFlow.signUp,
    this.licenseKey = '',
  });

  final _i48.Key? key;

  final String email;

  final String? password;

  final _i49.AuthFlow authFlow;

  final String licenseKey;

  @override
  String toString() {
    return 'ConfirmEmailArgs{key: $key, email: $email, password: $password, authFlow: $authFlow, licenseKey: $licenseKey}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ConfirmEmailArgs) return false;
    return key == other.key &&
        email == other.email &&
        password == other.password &&
        authFlow == other.authFlow &&
        licenseKey == other.licenseKey;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      email.hashCode ^
      password.hashCode ^
      authFlow.hashCode ^
      licenseKey.hashCode;
}

/// generated route for
/// [_i9.CreatePassword]
class CreatePassword extends _i47.PageRouteInfo<CreatePasswordArgs> {
  CreatePassword({
    _i48.Key? key,
    required String email,
    required _i49.AuthFlow authFlow,
    required String code,
    List<_i47.PageRouteInfo>? children,
  }) : super(
         CreatePassword.name,
         args: CreatePasswordArgs(
           key: key,
           email: email,
           authFlow: authFlow,
           code: code,
         ),
         initialChildren: children,
       );

  static const String name = 'CreatePassword';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<CreatePasswordArgs>();
      return _i9.CreatePassword(
        key: args.key,
        email: args.email,
        authFlow: args.authFlow,
        code: args.code,
      );
    },
  );
}

class CreatePasswordArgs {
  const CreatePasswordArgs({
    this.key,
    required this.email,
    required this.authFlow,
    required this.code,
  });

  final _i48.Key? key;

  final String email;

  final _i49.AuthFlow authFlow;

  final String code;

  @override
  String toString() {
    return 'CreatePasswordArgs{key: $key, email: $email, authFlow: $authFlow, code: $code}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CreatePasswordArgs) return false;
    return key == other.key &&
        email == other.email &&
        authFlow == other.authFlow &&
        code == other.code;
  }

  @override
  int get hashCode =>
      key.hashCode ^ email.hashCode ^ authFlow.hashCode ^ code.hashCode;
}

/// generated route for
/// [_i10.DeleteAccount]
class DeleteAccount extends _i47.PageRouteInfo<void> {
  const DeleteAccount({List<_i47.PageRouteInfo>? children})
    : super(DeleteAccount.name, initialChildren: children);

  static const String name = 'DeleteAccount';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      return const _i10.DeleteAccount();
    },
  );
}

/// generated route for
/// [_i11.DeveloperMode]
class DeveloperMode extends _i47.PageRouteInfo<void> {
  const DeveloperMode({List<_i47.PageRouteInfo>? children})
    : super(DeveloperMode.name, initialChildren: children);

  static const String name = 'DeveloperMode';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      return const _i11.DeveloperMode();
    },
  );
}

/// generated route for
/// [_i12.DeviceLimitReached]
class DeviceLimitReached extends _i47.PageRouteInfo<DeviceLimitReachedArgs> {
  DeviceLimitReached({
    _i48.Key? key,
    required List<_i50.DeviceModel> devices,
    List<_i47.PageRouteInfo>? children,
  }) : super(
         DeviceLimitReached.name,
         args: DeviceLimitReachedArgs(key: key, devices: devices),
         initialChildren: children,
       );

  static const String name = 'DeviceLimitReached';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<DeviceLimitReachedArgs>();
      return _i12.DeviceLimitReached(key: args.key, devices: args.devices);
    },
  );
}

class DeviceLimitReachedArgs {
  const DeviceLimitReachedArgs({this.key, required this.devices});

  final _i48.Key? key;

  final List<_i50.DeviceModel> devices;

  @override
  String toString() {
    return 'DeviceLimitReachedArgs{key: $key, devices: $devices}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DeviceLimitReachedArgs) return false;
    return key == other.key &&
        const _i51.ListEquality<_i50.DeviceModel>().equals(
          devices,
          other.devices,
        );
  }

  @override
  int get hashCode =>
      key.hashCode ^ const _i51.ListEquality<_i50.DeviceModel>().hash(devices);
}

/// generated route for
/// [_i13.DownloadLinks]
class DownloadLinks extends _i47.PageRouteInfo<void> {
  const DownloadLinks({List<_i47.PageRouteInfo>? children})
    : super(DownloadLinks.name, initialChildren: children);

  static const String name = 'DownloadLinks';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      return const _i13.DownloadLinks();
    },
  );
}

/// generated route for
/// [_i14.FollowUs]
class FollowUs extends _i47.PageRouteInfo<void> {
  const FollowUs({List<_i47.PageRouteInfo>? children})
    : super(FollowUs.name, initialChildren: children);

  static const String name = 'FollowUs';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      return const _i14.FollowUs();
    },
  );
}

/// generated route for
/// [_i15.HelpFriend]
class HelpFriend extends _i47.PageRouteInfo<HelpFriendArgs> {
  HelpFriend({
    _i48.Key? key,
    bool fromLink = false,
    List<_i47.PageRouteInfo>? children,
  }) : super(
         HelpFriend.name,
         args: HelpFriendArgs(key: key, fromLink: fromLink),
         initialChildren: children,
       );

  static const String name = 'HelpFriend';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<HelpFriendArgs>(
        orElse: () => const HelpFriendArgs(),
      );
      return _i15.HelpFriend(key: args.key, fromLink: args.fromLink);
    },
  );
}

class HelpFriendArgs {
  const HelpFriendArgs({this.key, this.fromLink = false});

  final _i48.Key? key;

  final bool fromLink;

  @override
  String toString() {
    return 'HelpFriendArgs{key: $key, fromLink: $fromLink}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! HelpFriendArgs) return false;
    return key == other.key && fromLink == other.fromLink;
  }

  @override
  int get hashCode => key.hashCode ^ fromLink.hashCode;
}

/// generated route for
/// [_i16.Home]
class Home extends _i47.PageRouteInfo<void> {
  const Home({List<_i47.PageRouteInfo>? children})
    : super(Home.name, initialChildren: children);

  static const String name = 'Home';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      return const _i16.Home();
    },
  );
}

/// generated route for
/// [_i17.InviteFriends]
class InviteFriends extends _i47.PageRouteInfo<void> {
  const InviteFriends({List<_i47.PageRouteInfo>? children})
    : super(InviteFriends.name, initialChildren: children);

  static const String name = 'InviteFriends';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      return const _i17.InviteFriends();
    },
  );
}

/// generated route for
/// [_i18.InviteShare]
class InviteShare extends _i47.PageRouteInfo<InviteShareArgs> {
  InviteShare({
    _i48.Key? key,
    required String inviteId,
    List<_i47.PageRouteInfo>? children,
  }) : super(
         InviteShare.name,
         args: InviteShareArgs(key: key, inviteId: inviteId),
         initialChildren: children,
       );

  static const String name = 'InviteShare';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<InviteShareArgs>();
      return _i18.InviteShare(key: args.key, inviteId: args.inviteId);
    },
  );
}

class InviteShareArgs {
  const InviteShareArgs({this.key, required this.inviteId});

  final _i48.Key? key;

  final String inviteId;

  @override
  String toString() {
    return 'InviteShareArgs{key: $key, inviteId: $inviteId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! InviteShareArgs) return false;
    return key == other.key && inviteId == other.inviteId;
  }

  @override
  int get hashCode => key.hashCode ^ inviteId.hashCode;
}

/// generated route for
/// [_i19.JoinPrivateServer]
class JoinPrivateServer extends _i47.PageRouteInfo<JoinPrivateServerArgs> {
  JoinPrivateServer({
    _i48.Key? key,
    Map<String, String>? deepLinkData,
    List<_i47.PageRouteInfo>? children,
  }) : super(
         JoinPrivateServer.name,
         args: JoinPrivateServerArgs(key: key, deepLinkData: deepLinkData),
         initialChildren: children,
       );

  static const String name = 'JoinPrivateServer';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<JoinPrivateServerArgs>(
        orElse: () => const JoinPrivateServerArgs(),
      );
      return _i19.JoinPrivateServer(
        key: args.key,
        deepLinkData: args.deepLinkData,
      );
    },
  );
}

class JoinPrivateServerArgs {
  const JoinPrivateServerArgs({this.key, this.deepLinkData});

  final _i48.Key? key;

  final Map<String, String>? deepLinkData;

  @override
  String toString() {
    return 'JoinPrivateServerArgs{key: $key, deepLinkData: $deepLinkData}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! JoinPrivateServerArgs) return false;
    return key == other.key &&
        const _i51.MapEquality<String, String>().equals(
          deepLinkData,
          other.deepLinkData,
        );
  }

  @override
  int get hashCode =>
      key.hashCode ^
      const _i51.MapEquality<String, String>().hash(deepLinkData);
}

/// generated route for
/// [_i20.Language]
class Language extends _i47.PageRouteInfo<void> {
  const Language({List<_i47.PageRouteInfo>? children})
    : super(Language.name, initialChildren: children);

  static const String name = 'Language';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      return const _i20.Language();
    },
  );
}

/// generated route for
/// [_i21.LanternProLicense]
class LanternProLicense extends _i47.PageRouteInfo<LanternProLicenseArgs> {
  LanternProLicense({
    _i48.Key? key,
    required String email,
    required String code,
    String licenseKey = '',
    List<_i47.PageRouteInfo>? children,
  }) : super(
         LanternProLicense.name,
         args: LanternProLicenseArgs(
           key: key,
           email: email,
           code: code,
           licenseKey: licenseKey,
         ),
         initialChildren: children,
       );

  static const String name = 'LanternProLicense';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<LanternProLicenseArgs>();
      return _i21.LanternProLicense(
        key: args.key,
        email: args.email,
        code: args.code,
        licenseKey: args.licenseKey,
      );
    },
  );
}

class LanternProLicenseArgs {
  const LanternProLicenseArgs({
    this.key,
    required this.email,
    required this.code,
    this.licenseKey = '',
  });

  final _i48.Key? key;

  final String email;

  final String code;

  final String licenseKey;

  @override
  String toString() {
    return 'LanternProLicenseArgs{key: $key, email: $email, code: $code, licenseKey: $licenseKey}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LanternProLicenseArgs) return false;
    return key == other.key &&
        email == other.email &&
        code == other.code &&
        licenseKey == other.licenseKey;
  }

  @override
  int get hashCode =>
      key.hashCode ^ email.hashCode ^ code.hashCode ^ licenseKey.hashCode;
}

/// generated route for
/// [_i22.Logs]
class Logs extends _i47.PageRouteInfo<void> {
  const Logs({List<_i47.PageRouteInfo>? children})
    : super(Logs.name, initialChildren: children);

  static const String name = 'Logs';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      return const _i22.Logs();
    },
  );
}

/// generated route for
/// [_i23.MacOSExtensionDialog]
class MacOSExtensionDialog extends _i47.PageRouteInfo<void> {
  const MacOSExtensionDialog({List<_i47.PageRouteInfo>? children})
    : super(MacOSExtensionDialog.name, initialChildren: children);

  static const String name = 'MacOSExtensionDialog';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      return const _i23.MacOSExtensionDialog();
    },
  );
}

/// generated route for
/// [_i24.ManagePrivateServer]
class ManagePrivateServer extends _i47.PageRouteInfo<void> {
  const ManagePrivateServer({List<_i47.PageRouteInfo>? children})
    : super(ManagePrivateServer.name, initialChildren: children);

  static const String name = 'ManagePrivateServer';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      return const _i24.ManagePrivateServer();
    },
  );
}

/// generated route for
/// [_i25.ManuallyServerSetup]
class ManuallyServerSetup extends _i47.PageRouteInfo<void> {
  const ManuallyServerSetup({List<_i47.PageRouteInfo>? children})
    : super(ManuallyServerSetup.name, initialChildren: children);

  static const String name = 'ManuallyServerSetup';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      return const _i25.ManuallyServerSetup();
    },
  );
}

/// generated route for
/// [_i26.Onboarding]
class Onboarding extends _i47.PageRouteInfo<void> {
  const Onboarding({List<_i47.PageRouteInfo>? children})
    : super(Onboarding.name, initialChildren: children);

  static const String name = 'Onboarding';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      return const _i26.Onboarding();
    },
  );
}

/// generated route for
/// [_i27.Plans]
class Plans extends _i47.PageRouteInfo<PlansArgs> {
  Plans({
    _i48.Key? key,
    String? referralCode,
    List<_i47.PageRouteInfo>? children,
  }) : super(
         Plans.name,
         args: PlansArgs(key: key, referralCode: referralCode),
         initialChildren: children,
       );

  static const String name = 'Plans';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<PlansArgs>(orElse: () => const PlansArgs());
      return _i27.Plans(key: args.key, referralCode: args.referralCode);
    },
  );
}

class PlansArgs {
  const PlansArgs({this.key, this.referralCode});

  final _i48.Key? key;

  final String? referralCode;

  @override
  String toString() {
    return 'PlansArgs{key: $key, referralCode: $referralCode}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PlansArgs) return false;
    return key == other.key && referralCode == other.referralCode;
  }

  @override
  int get hashCode => key.hashCode ^ referralCode.hashCode;
}

/// generated route for
/// [_i28.PrivateServerAddBilling]
class PrivateServerAddBilling extends _i47.PageRouteInfo<void> {
  const PrivateServerAddBilling({List<_i47.PageRouteInfo>? children})
    : super(PrivateServerAddBilling.name, initialChildren: children);

  static const String name = 'PrivateServerAddBilling';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      return const _i28.PrivateServerAddBilling();
    },
  );
}

/// generated route for
/// [_i29.PrivateServerDeploy]
class PrivateServerDeploy extends _i47.PageRouteInfo<PrivateServerDeployArgs> {
  PrivateServerDeploy({
    _i48.Key? key,
    required String serverName,
    List<_i47.PageRouteInfo>? children,
  }) : super(
         PrivateServerDeploy.name,
         args: PrivateServerDeployArgs(key: key, serverName: serverName),
         initialChildren: children,
       );

  static const String name = 'PrivateServerDeploy';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<PrivateServerDeployArgs>();
      return _i29.PrivateServerDeploy(
        key: args.key,
        serverName: args.serverName,
      );
    },
  );
}

class PrivateServerDeployArgs {
  const PrivateServerDeployArgs({this.key, required this.serverName});

  final _i48.Key? key;

  final String serverName;

  @override
  String toString() {
    return 'PrivateServerDeployArgs{key: $key, serverName: $serverName}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PrivateServerDeployArgs) return false;
    return key == other.key && serverName == other.serverName;
  }

  @override
  int get hashCode => key.hashCode ^ serverName.hashCode;
}

/// generated route for
/// [_i30.PrivateServerLocation]
class PrivateServerLocation
    extends _i47.PageRouteInfo<PrivateServerLocationArgs> {
  PrivateServerLocation({
    _i48.Key? key,
    required List<String> location,
    required String? selectedLocation,
    required dynamic Function(String) onLocationSelected,
    required _i49.CloudProvider provider,
    List<_i47.PageRouteInfo>? children,
  }) : super(
         PrivateServerLocation.name,
         args: PrivateServerLocationArgs(
           key: key,
           location: location,
           selectedLocation: selectedLocation,
           onLocationSelected: onLocationSelected,
           provider: provider,
         ),
         initialChildren: children,
       );

  static const String name = 'PrivateServerLocation';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<PrivateServerLocationArgs>();
      return _i30.PrivateServerLocation(
        key: args.key,
        location: args.location,
        selectedLocation: args.selectedLocation,
        onLocationSelected: args.onLocationSelected,
        provider: args.provider,
      );
    },
  );
}

class PrivateServerLocationArgs {
  const PrivateServerLocationArgs({
    this.key,
    required this.location,
    required this.selectedLocation,
    required this.onLocationSelected,
    required this.provider,
  });

  final _i48.Key? key;

  final List<String> location;

  final String? selectedLocation;

  final dynamic Function(String) onLocationSelected;

  final _i49.CloudProvider provider;

  @override
  String toString() {
    return 'PrivateServerLocationArgs{key: $key, location: $location, selectedLocation: $selectedLocation, onLocationSelected: $onLocationSelected, provider: $provider}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PrivateServerLocationArgs) return false;
    return key == other.key &&
        const _i51.ListEquality<String>().equals(location, other.location) &&
        selectedLocation == other.selectedLocation &&
        provider == other.provider;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      const _i51.ListEquality<String>().hash(location) ^
      selectedLocation.hashCode ^
      provider.hashCode;
}

/// generated route for
/// [_i31.PrivateServerSetup]
class PrivateServerSetup extends _i47.PageRouteInfo<void> {
  const PrivateServerSetup({List<_i47.PageRouteInfo>? children})
    : super(PrivateServerSetup.name, initialChildren: children);

  static const String name = 'PrivateServerSetup';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      return const _i31.PrivateServerSetup();
    },
  );
}

/// generated route for
/// [_i32.PrivateSeverDetails]
class PrivateServerDetails
    extends _i47.PageRouteInfo<PrivateServerDetailsArgs> {
  PrivateServerDetails({
    _i48.Key? key,
    required List<String> accounts,
    required _i49.CloudProvider provider,
    bool isPreFilled = false,
    List<_i47.PageRouteInfo>? children,
  }) : super(
         PrivateServerDetails.name,
         args: PrivateServerDetailsArgs(
           key: key,
           accounts: accounts,
           provider: provider,
           isPreFilled: isPreFilled,
         ),
         initialChildren: children,
       );

  static const String name = 'PrivateServerDetails';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<PrivateServerDetailsArgs>();
      return _i32.PrivateSeverDetails(
        key: args.key,
        accounts: args.accounts,
        provider: args.provider,
        isPreFilled: args.isPreFilled,
      );
    },
  );
}

class PrivateServerDetailsArgs {
  const PrivateServerDetailsArgs({
    this.key,
    required this.accounts,
    required this.provider,
    this.isPreFilled = false,
  });

  final _i48.Key? key;

  final List<String> accounts;

  final _i49.CloudProvider provider;

  final bool isPreFilled;

  @override
  String toString() {
    return 'PrivateServerDetailsArgs{key: $key, accounts: $accounts, provider: $provider, isPreFilled: $isPreFilled}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PrivateServerDetailsArgs) return false;
    return key == other.key &&
        const _i51.ListEquality<String>().equals(accounts, other.accounts) &&
        provider == other.provider &&
        isPreFilled == other.isPreFilled;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      const _i51.ListEquality<String>().hash(accounts) ^
      provider.hashCode ^
      isPreFilled.hashCode;
}

/// generated route for
/// [_i33.QrCodeScanner]
class QrCodeScanner extends _i47.PageRouteInfo<void> {
  const QrCodeScanner({List<_i47.PageRouteInfo>? children})
    : super(QrCodeScanner.name, initialChildren: children);

  static const String name = 'QrCodeScanner';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      return const _i33.QrCodeScanner();
    },
  );
}

/// generated route for
/// [_i34.ReportIssue]
class ReportIssue extends _i47.PageRouteInfo<ReportIssueArgs> {
  ReportIssue({
    _i48.Key? key,
    String? description,
    String? type,
    List<_i47.PageRouteInfo>? children,
  }) : super(
         ReportIssue.name,
         args: ReportIssueArgs(key: key, description: description, type: type),
         initialChildren: children,
       );

  static const String name = 'ReportIssue';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ReportIssueArgs>(
        orElse: () => const ReportIssueArgs(),
      );
      return _i34.ReportIssue(
        key: args.key,
        description: args.description,
        type: args.type,
      );
    },
  );
}

class ReportIssueArgs {
  const ReportIssueArgs({this.key, this.description, this.type});

  final _i48.Key? key;

  final String? description;

  final String? type;

  @override
  String toString() {
    return 'ReportIssueArgs{key: $key, description: $description, type: $type}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ReportIssueArgs) return false;
    return key == other.key &&
        description == other.description &&
        type == other.type;
  }

  @override
  int get hashCode => key.hashCode ^ description.hashCode ^ type.hashCode;
}

/// generated route for
/// [_i35.ResetPassword]
class ResetPassword extends _i47.PageRouteInfo<ResetPasswordArgs> {
  ResetPassword({
    _i48.Key? key,
    required String email,
    required String code,
    List<_i47.PageRouteInfo>? children,
  }) : super(
         ResetPassword.name,
         args: ResetPasswordArgs(key: key, email: email, code: code),
         initialChildren: children,
       );

  static const String name = 'ResetPassword';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ResetPasswordArgs>();
      return _i35.ResetPassword(
        key: args.key,
        email: args.email,
        code: args.code,
      );
    },
  );
}

class ResetPasswordArgs {
  const ResetPasswordArgs({this.key, required this.email, required this.code});

  final _i48.Key? key;

  final String email;

  final String code;

  @override
  String toString() {
    return 'ResetPasswordArgs{key: $key, email: $email, code: $code}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ResetPasswordArgs) return false;
    return key == other.key && email == other.email && code == other.code;
  }

  @override
  int get hashCode => key.hashCode ^ email.hashCode ^ code.hashCode;
}

/// generated route for
/// [_i36.ResetPasswordEmail]
class ResetPasswordEmail extends _i47.PageRouteInfo<ResetPasswordEmailArgs> {
  ResetPasswordEmail({
    _i48.Key? key,
    String? email,
    List<_i47.PageRouteInfo>? children,
  }) : super(
         ResetPasswordEmail.name,
         args: ResetPasswordEmailArgs(key: key, email: email),
         initialChildren: children,
       );

  static const String name = 'ResetPasswordEmail';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ResetPasswordEmailArgs>(
        orElse: () => const ResetPasswordEmailArgs(),
      );
      return _i36.ResetPasswordEmail(key: args.key, email: args.email);
    },
  );
}

class ResetPasswordEmailArgs {
  const ResetPasswordEmailArgs({this.key, this.email});

  final _i48.Key? key;

  final String? email;

  @override
  String toString() {
    return 'ResetPasswordEmailArgs{key: $key, email: $email}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ResetPasswordEmailArgs) return false;
    return key == other.key && email == other.email;
  }

  @override
  int get hashCode => key.hashCode ^ email.hashCode;
}

/// generated route for
/// [_i37.ServerSelection]
class ServerSelection extends _i47.PageRouteInfo<void> {
  const ServerSelection({List<_i47.PageRouteInfo>? children})
    : super(ServerSelection.name, initialChildren: children);

  static const String name = 'ServerSelection';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      return const _i37.ServerSelection();
    },
  );
}

/// generated route for
/// [_i38.Setting]
class Setting extends _i47.PageRouteInfo<void> {
  const Setting({List<_i47.PageRouteInfo>? children})
    : super(Setting.name, initialChildren: children);

  static const String name = 'Setting';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      return const _i38.Setting();
    },
  );
}

/// generated route for
/// [_i39.SignInEmail]
class SignInEmail extends _i47.PageRouteInfo<void> {
  const SignInEmail({List<_i47.PageRouteInfo>? children})
    : super(SignInEmail.name, initialChildren: children);

  static const String name = 'SignInEmail';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      return const _i39.SignInEmail();
    },
  );
}

/// generated route for
/// [_i40.SignInPassword]
class SignInPassword extends _i47.PageRouteInfo<SignInPasswordArgs> {
  SignInPassword({
    _i48.Key? key,
    required String email,
    bool fromChangeEmail = false,
    List<_i47.PageRouteInfo>? children,
  }) : super(
         SignInPassword.name,
         args: SignInPasswordArgs(
           key: key,
           email: email,
           fromChangeEmail: fromChangeEmail,
         ),
         initialChildren: children,
       );

  static const String name = 'SignInPassword';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SignInPasswordArgs>();
      return _i40.SignInPassword(
        key: args.key,
        email: args.email,
        fromChangeEmail: args.fromChangeEmail,
      );
    },
  );
}

class SignInPasswordArgs {
  const SignInPasswordArgs({
    this.key,
    required this.email,
    this.fromChangeEmail = false,
  });

  final _i48.Key? key;

  final String email;

  final bool fromChangeEmail;

  @override
  String toString() {
    return 'SignInPasswordArgs{key: $key, email: $email, fromChangeEmail: $fromChangeEmail}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SignInPasswordArgs) return false;
    return key == other.key &&
        email == other.email &&
        fromChangeEmail == other.fromChangeEmail;
  }

  @override
  int get hashCode => key.hashCode ^ email.hashCode ^ fromChangeEmail.hashCode;
}

/// generated route for
/// [_i41.SmartRouting]
class SmartRouting extends _i47.PageRouteInfo<void> {
  const SmartRouting({List<_i47.PageRouteInfo>? children})
    : super(SmartRouting.name, initialChildren: children);

  static const String name = 'SmartRouting';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      return const _i41.SmartRouting();
    },
  );
}

/// generated route for
/// [_i42.SplitTunneling]
class SplitTunneling extends _i47.PageRouteInfo<void> {
  const SplitTunneling({List<_i47.PageRouteInfo>? children})
    : super(SplitTunneling.name, initialChildren: children);

  static const String name = 'SplitTunneling';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      return const _i42.SplitTunneling();
    },
  );
}

/// generated route for
/// [_i43.SplitTunnelingInfo]
class SplitTunnelingInfo extends _i47.PageRouteInfo<void> {
  const SplitTunnelingInfo({List<_i47.PageRouteInfo>? children})
    : super(SplitTunnelingInfo.name, initialChildren: children);

  static const String name = 'SplitTunnelingInfo';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      return const _i43.SplitTunnelingInfo();
    },
  );
}

/// generated route for
/// [_i44.Support]
class Support extends _i47.PageRouteInfo<void> {
  const Support({List<_i47.PageRouteInfo>? children})
    : super(Support.name, initialChildren: children);

  static const String name = 'Support';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      return const _i44.Support();
    },
  );
}

/// generated route for
/// [_i45.VPNSetting]
class VPNSetting extends _i47.PageRouteInfo<void> {
  const VPNSetting({List<_i47.PageRouteInfo>? children})
    : super(VPNSetting.name, initialChildren: children);

  static const String name = 'VPNSetting';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      return const _i45.VPNSetting();
    },
  );
}

/// generated route for
/// [_i46.WebsiteSplitTunneling]
class WebsiteSplitTunneling extends _i47.PageRouteInfo<void> {
  const WebsiteSplitTunneling({List<_i47.PageRouteInfo>? children})
    : super(WebsiteSplitTunneling.name, initialChildren: children);

  static const String name = 'WebsiteSplitTunneling';

  static _i47.PageInfo page = _i47.PageInfo(
    name,
    builder: (data) {
      return const _i46.WebsiteSplitTunneling();
    },
  );
}
