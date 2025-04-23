// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:auto_route/auto_route.dart' as _i29;
import 'package:flutter/material.dart' as _i30;
import 'package:lantern/core/common/common.dart' as _i31;
import 'package:lantern/core/widgets/app_webview.dart' as _i4;
import 'package:lantern/features/account/account.dart' as _i1;
import 'package:lantern/features/account/delete_account.dart' as _i9;
import 'package:lantern/features/auth/activation_code.dart' as _i2;
import 'package:lantern/features/auth/add_email.dart' as _i3;
import 'package:lantern/features/auth/choose_payment_method.dart' as _i6;
import 'package:lantern/features/auth/confirm_email.dart' as _i7;
import 'package:lantern/features/auth/create_password.dart' as _i8;
import 'package:lantern/features/auth/reset_password.dart' as _i18;
import 'package:lantern/features/auth/reset_password_email.dart' as _i19;
import 'package:lantern/features/auth/sign_in_email.dart' as _i22;
import 'package:lantern/features/auth/sign_in_password.dart' as _i23;
import 'package:lantern/features/home/home.dart' as _i12;
import 'package:lantern/features/language/language.dart' as _i14;
import 'package:lantern/features/logs/logs.dart' as _i15;
import 'package:lantern/features/plans/plans.dart' as _i16;
import 'package:lantern/features/reportIssue/report_issue.dart' as _i17;
import 'package:lantern/features/setting/download_links.dart' as _i10;
import 'package:lantern/features/setting/follow_us.dart' as _i11;
import 'package:lantern/features/setting/invite_friends.dart' as _i13;
import 'package:lantern/features/setting/setting.dart' as _i21;
import 'package:lantern/features/setting/vpn_setting.dart' as _i27;
import 'package:lantern/features/split_tunneling/apps_split_tunneling.dart'
    as _i5;
import 'package:lantern/features/split_tunneling/split_tunneling.dart' as _i24;
import 'package:lantern/features/split_tunneling/split_tunneling_info.dart'
    as _i25;
import 'package:lantern/features/split_tunneling/website_split_tunneling.dart'
    as _i28;
import 'package:lantern/features/support/support.dart' as _i26;
import 'package:lantern/features/vpn/server_selection.dart' as _i20;

/// generated route for
/// [_i1.Account]
class Account extends _i29.PageRouteInfo<void> {
  const Account({List<_i29.PageRouteInfo>? children})
      : super(
          Account.name,
          initialChildren: children,
        );

  static const String name = 'Account';

  static _i29.PageInfo page = _i29.PageInfo(
    name,
    builder: (data) {
      return const _i1.Account();
    },
  );
}

/// generated route for
/// [_i2.ActivationCode]
class ActivationCode extends _i29.PageRouteInfo<void> {
  const ActivationCode({List<_i29.PageRouteInfo>? children})
      : super(
          ActivationCode.name,
          initialChildren: children,
        );

  static const String name = 'ActivationCode';

  static _i29.PageInfo page = _i29.PageInfo(
    name,
    builder: (data) {
      return const _i2.ActivationCode();
    },
  );
}

/// generated route for
/// [_i3.AddEmail]
class AddEmail extends _i29.PageRouteInfo<AddEmailArgs> {
  AddEmail({
    _i30.Key? key,
    _i31.AuthFlow authFlow = _i31.AuthFlow.signUp,
    _i31.AppFlow appFlow = _i31.AppFlow.nonStore,
    List<_i29.PageRouteInfo>? children,
  }) : super(
          AddEmail.name,
          args: AddEmailArgs(
            key: key,
            authFlow: authFlow,
            appFlow: appFlow,
          ),
          initialChildren: children,
        );

  static const String name = 'AddEmail';

  static _i29.PageInfo page = _i29.PageInfo(
    name,
    builder: (data) {
      final args =
          data.argsAs<AddEmailArgs>(orElse: () => const AddEmailArgs());
      return _i3.AddEmail(
        key: args.key,
        authFlow: args.authFlow,
        appFlow: args.appFlow,
      );
    },
  );
}

class AddEmailArgs {
  const AddEmailArgs({
    this.key,
    this.authFlow = _i31.AuthFlow.signUp,
    this.appFlow = _i31.AppFlow.nonStore,
  });

  final _i30.Key? key;

  final _i31.AuthFlow authFlow;

  final _i31.AppFlow appFlow;

  @override
  String toString() {
    return 'AddEmailArgs{key: $key, authFlow: $authFlow, appFlow: $appFlow}';
  }
}

/// generated route for
/// [_i4.AppWebView]
class AppWebview extends _i29.PageRouteInfo<AppWebviewArgs> {
  AppWebview({
    _i30.Key? key,
    required String title,
    required String url,
    List<_i29.PageRouteInfo>? children,
  }) : super(
          AppWebview.name,
          args: AppWebviewArgs(
            key: key,
            title: title,
            url: url,
          ),
          initialChildren: children,
        );

  static const String name = 'AppWebview';

  static _i29.PageInfo page = _i29.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<AppWebviewArgs>();
      return _i4.AppWebView(
        key: args.key,
        title: args.title,
        url: args.url,
      );
    },
  );
}

class AppWebviewArgs {
  const AppWebviewArgs({
    this.key,
    required this.title,
    required this.url,
  });

  final _i30.Key? key;

  final String title;

  final String url;

  @override
  String toString() {
    return 'AppWebviewArgs{key: $key, title: $title, url: $url}';
  }
}

/// generated route for
/// [_i5.AppsSplitTunneling]
class AppsSplitTunneling extends _i29.PageRouteInfo<void> {
  const AppsSplitTunneling({List<_i29.PageRouteInfo>? children})
      : super(
          AppsSplitTunneling.name,
          initialChildren: children,
        );

  static const String name = 'AppsSplitTunneling';

  static _i29.PageInfo page = _i29.PageInfo(
    name,
    builder: (data) {
      return const _i5.AppsSplitTunneling();
    },
  );
}

/// generated route for
/// [_i6.ChoosePaymentMethod]
class ChoosePaymentMethod extends _i29.PageRouteInfo<void> {
  const ChoosePaymentMethod({List<_i29.PageRouteInfo>? children})
      : super(
          ChoosePaymentMethod.name,
          initialChildren: children,
        );

  static const String name = 'ChoosePaymentMethod';

  static _i29.PageInfo page = _i29.PageInfo(
    name,
    builder: (data) {
      return const _i6.ChoosePaymentMethod();
    },
  );
}

/// generated route for
/// [_i7.ConfirmEmail]
class ConfirmEmail extends _i29.PageRouteInfo<ConfirmEmailArgs> {
  ConfirmEmail({
    _i30.Key? key,
    required String email,
    _i31.AuthFlow authFlow = _i31.AuthFlow.signUp,
    List<_i29.PageRouteInfo>? children,
  }) : super(
          ConfirmEmail.name,
          args: ConfirmEmailArgs(
            key: key,
            email: email,
            authFlow: authFlow,
          ),
          initialChildren: children,
        );

  static const String name = 'ConfirmEmail';

  static _i29.PageInfo page = _i29.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ConfirmEmailArgs>();
      return _i7.ConfirmEmail(
        key: args.key,
        email: args.email,
        authFlow: args.authFlow,
      );
    },
  );
}

class ConfirmEmailArgs {
  const ConfirmEmailArgs({
    this.key,
    required this.email,
    this.authFlow = _i31.AuthFlow.signUp,
  });

  final _i30.Key? key;

  final String email;

  final _i31.AuthFlow authFlow;

  @override
  String toString() {
    return 'ConfirmEmailArgs{key: $key, email: $email, authFlow: $authFlow}';
  }
}

/// generated route for
/// [_i8.CreatePassword]
class CreatePassword extends _i29.PageRouteInfo<CreatePasswordArgs> {
  CreatePassword({
    _i30.Key? key,
    required String email,
    List<_i29.PageRouteInfo>? children,
  }) : super(
          CreatePassword.name,
          args: CreatePasswordArgs(
            key: key,
            email: email,
          ),
          initialChildren: children,
        );

  static const String name = 'CreatePassword';

  static _i29.PageInfo page = _i29.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<CreatePasswordArgs>();
      return _i8.CreatePassword(
        key: args.key,
        email: args.email,
      );
    },
  );
}

class CreatePasswordArgs {
  const CreatePasswordArgs({
    this.key,
    required this.email,
  });

  final _i30.Key? key;

  final String email;

  @override
  String toString() {
    return 'CreatePasswordArgs{key: $key, email: $email}';
  }
}

/// generated route for
/// [_i9.DeleteAccount]
class DeleteAccount extends _i29.PageRouteInfo<void> {
  const DeleteAccount({List<_i29.PageRouteInfo>? children})
      : super(
          DeleteAccount.name,
          initialChildren: children,
        );

  static const String name = 'DeleteAccount';

  static _i29.PageInfo page = _i29.PageInfo(
    name,
    builder: (data) {
      return const _i9.DeleteAccount();
    },
  );
}

/// generated route for
/// [_i10.DownloadLinks]
class DownloadLinks extends _i29.PageRouteInfo<void> {
  const DownloadLinks({List<_i29.PageRouteInfo>? children})
      : super(
          DownloadLinks.name,
          initialChildren: children,
        );

  static const String name = 'DownloadLinks';

  static _i29.PageInfo page = _i29.PageInfo(
    name,
    builder: (data) {
      return const _i10.DownloadLinks();
    },
  );
}

/// generated route for
/// [_i11.FollowUs]
class FollowUs extends _i29.PageRouteInfo<FollowUsArgs> {
  FollowUs({
    _i30.Key? key,
    List<_i29.PageRouteInfo>? children,
  }) : super(
          FollowUs.name,
          args: FollowUsArgs(key: key),
          initialChildren: children,
        );

  static const String name = 'FollowUs';

  static _i29.PageInfo page = _i29.PageInfo(
    name,
    builder: (data) {
      final args =
          data.argsAs<FollowUsArgs>(orElse: () => const FollowUsArgs());
      return _i11.FollowUs(key: args.key);
    },
  );
}

class FollowUsArgs {
  const FollowUsArgs({this.key});

  final _i30.Key? key;

  @override
  String toString() {
    return 'FollowUsArgs{key: $key}';
  }
}

/// generated route for
/// [_i12.Home]
class Home extends _i29.PageRouteInfo<HomeArgs> {
  Home({
    _i30.Key? key,
    List<_i29.PageRouteInfo>? children,
  }) : super(
          Home.name,
          args: HomeArgs(key: key),
          initialChildren: children,
        );

  static const String name = 'Home';

  static _i29.PageInfo page = _i29.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<HomeArgs>(orElse: () => const HomeArgs());
      return _i12.Home(key: args.key);
    },
  );
}

class HomeArgs {
  const HomeArgs({this.key});

  final _i30.Key? key;

  @override
  String toString() {
    return 'HomeArgs{key: $key}';
  }
}

/// generated route for
/// [_i13.InviteFriends]
class InviteFriends extends _i29.PageRouteInfo<void> {
  const InviteFriends({List<_i29.PageRouteInfo>? children})
      : super(
          InviteFriends.name,
          initialChildren: children,
        );

  static const String name = 'InviteFriends';

  static _i29.PageInfo page = _i29.PageInfo(
    name,
    builder: (data) {
      return const _i13.InviteFriends();
    },
  );
}

/// generated route for
/// [_i14.Language]
class Language extends _i29.PageRouteInfo<void> {
  const Language({List<_i29.PageRouteInfo>? children})
      : super(
          Language.name,
          initialChildren: children,
        );

  static const String name = 'Language';

  static _i29.PageInfo page = _i29.PageInfo(
    name,
    builder: (data) {
      return const _i14.Language();
    },
  );
}

/// generated route for
/// [_i15.Logs]
class Logs extends _i29.PageRouteInfo<void> {
  const Logs({List<_i29.PageRouteInfo>? children})
      : super(
          Logs.name,
          initialChildren: children,
        );

  static const String name = 'Logs';

  static _i29.PageInfo page = _i29.PageInfo(
    name,
    builder: (data) {
      return const _i15.Logs();
    },
  );
}

/// generated route for
/// [_i16.Plans]
class Plans extends _i29.PageRouteInfo<void> {
  const Plans({List<_i29.PageRouteInfo>? children})
      : super(
          Plans.name,
          initialChildren: children,
        );

  static const String name = 'Plans';

  static _i29.PageInfo page = _i29.PageInfo(
    name,
    builder: (data) {
      return const _i16.Plans();
    },
  );
}

/// generated route for
/// [_i17.ReportIssue]
class ReportIssue extends _i29.PageRouteInfo<ReportIssueArgs> {
  ReportIssue({
    _i30.Key? key,
    String? description,
    List<_i29.PageRouteInfo>? children,
  }) : super(
          ReportIssue.name,
          args: ReportIssueArgs(
            key: key,
            description: description,
          ),
          initialChildren: children,
        );

  static const String name = 'ReportIssue';

  static _i29.PageInfo page = _i29.PageInfo(
    name,
    builder: (data) {
      final args =
          data.argsAs<ReportIssueArgs>(orElse: () => const ReportIssueArgs());
      return _i17.ReportIssue(
        key: args.key,
        description: args.description,
      );
    },
  );
}

class ReportIssueArgs {
  const ReportIssueArgs({
    this.key,
    this.description,
  });

  final _i30.Key? key;

  final String? description;

  @override
  String toString() {
    return 'ReportIssueArgs{key: $key, description: $description}';
  }
}

/// generated route for
/// [_i18.ResetPassword]
class ResetPassword extends _i29.PageRouteInfo<ResetPasswordArgs> {
  ResetPassword({
    _i30.Key? key,
    required String email,
    List<_i29.PageRouteInfo>? children,
  }) : super(
          ResetPassword.name,
          args: ResetPasswordArgs(
            key: key,
            email: email,
          ),
          initialChildren: children,
        );

  static const String name = 'ResetPassword';

  static _i29.PageInfo page = _i29.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ResetPasswordArgs>();
      return _i18.ResetPassword(
        key: args.key,
        email: args.email,
      );
    },
  );
}

class ResetPasswordArgs {
  const ResetPasswordArgs({
    this.key,
    required this.email,
  });

  final _i30.Key? key;

  final String email;

  @override
  String toString() {
    return 'ResetPasswordArgs{key: $key, email: $email}';
  }
}

/// generated route for
/// [_i19.ResetPasswordEmail]
class ResetPasswordEmail extends _i29.PageRouteInfo<void> {
  const ResetPasswordEmail({List<_i29.PageRouteInfo>? children})
      : super(
          ResetPasswordEmail.name,
          initialChildren: children,
        );

  static const String name = 'ResetPasswordEmail';

  static _i29.PageInfo page = _i29.PageInfo(
    name,
    builder: (data) {
      return const _i19.ResetPasswordEmail();
    },
  );
}

/// generated route for
/// [_i20.ServerSelection]
class ServerSelection extends _i29.PageRouteInfo<void> {
  const ServerSelection({List<_i29.PageRouteInfo>? children})
      : super(
          ServerSelection.name,
          initialChildren: children,
        );

  static const String name = 'ServerSelection';

  static _i29.PageInfo page = _i29.PageInfo(
    name,
    builder: (data) {
      return const _i20.ServerSelection();
    },
  );
}

/// generated route for
/// [_i21.Setting]
class Setting extends _i29.PageRouteInfo<SettingArgs> {
  Setting({
    _i30.Key? key,
    List<_i29.PageRouteInfo>? children,
  }) : super(
          Setting.name,
          args: SettingArgs(key: key),
          initialChildren: children,
        );

  static const String name = 'Setting';

  static _i29.PageInfo page = _i29.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SettingArgs>(orElse: () => const SettingArgs());
      return _i21.Setting(key: args.key);
    },
  );
}

class SettingArgs {
  const SettingArgs({this.key});

  final _i30.Key? key;

  @override
  String toString() {
    return 'SettingArgs{key: $key}';
  }
}

/// generated route for
/// [_i22.SignInEmail]
class SignInEmail extends _i29.PageRouteInfo<void> {
  const SignInEmail({List<_i29.PageRouteInfo>? children})
      : super(
          SignInEmail.name,
          initialChildren: children,
        );

  static const String name = 'SignInEmail';

  static _i29.PageInfo page = _i29.PageInfo(
    name,
    builder: (data) {
      return const _i22.SignInEmail();
    },
  );
}

/// generated route for
/// [_i23.SignInPassword]
class SignInPassword extends _i29.PageRouteInfo<SignInPasswordArgs> {
  SignInPassword({
    _i30.Key? key,
    required String email,
    List<_i29.PageRouteInfo>? children,
  }) : super(
          SignInPassword.name,
          args: SignInPasswordArgs(
            key: key,
            email: email,
          ),
          initialChildren: children,
        );

  static const String name = 'SignInPassword';

  static _i29.PageInfo page = _i29.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SignInPasswordArgs>();
      return _i23.SignInPassword(
        key: args.key,
        email: args.email,
      );
    },
  );
}

class SignInPasswordArgs {
  const SignInPasswordArgs({
    this.key,
    required this.email,
  });

  final _i30.Key? key;

  final String email;

  @override
  String toString() {
    return 'SignInPasswordArgs{key: $key, email: $email}';
  }
}

/// generated route for
/// [_i24.SplitTunneling]
class SplitTunneling extends _i29.PageRouteInfo<void> {
  const SplitTunneling({List<_i29.PageRouteInfo>? children})
      : super(
          SplitTunneling.name,
          initialChildren: children,
        );

  static const String name = 'SplitTunneling';

  static _i29.PageInfo page = _i29.PageInfo(
    name,
    builder: (data) {
      return const _i24.SplitTunneling();
    },
  );
}

/// generated route for
/// [_i25.SplitTunnelingInfo]
class SplitTunnelingInfo extends _i29.PageRouteInfo<void> {
  const SplitTunnelingInfo({List<_i29.PageRouteInfo>? children})
      : super(
          SplitTunnelingInfo.name,
          initialChildren: children,
        );

  static const String name = 'SplitTunnelingInfo';

  static _i29.PageInfo page = _i29.PageInfo(
    name,
    builder: (data) {
      return const _i25.SplitTunnelingInfo();
    },
  );
}

/// generated route for
/// [_i26.Support]
class Support extends _i29.PageRouteInfo<void> {
  const Support({List<_i29.PageRouteInfo>? children})
      : super(
          Support.name,
          initialChildren: children,
        );

  static const String name = 'Support';

  static _i29.PageInfo page = _i29.PageInfo(
    name,
    builder: (data) {
      return const _i26.Support();
    },
  );
}

/// generated route for
/// [_i27.VPNSetting]
class VPNSetting extends _i29.PageRouteInfo<void> {
  const VPNSetting({List<_i29.PageRouteInfo>? children})
      : super(
          VPNSetting.name,
          initialChildren: children,
        );

  static const String name = 'VPNSetting';

  static _i29.PageInfo page = _i29.PageInfo(
    name,
    builder: (data) {
      return const _i27.VPNSetting();
    },
  );
}

/// generated route for
/// [_i28.WebsiteSplitTunneling]
class WebsiteSplitTunneling extends _i29.PageRouteInfo<void> {
  const WebsiteSplitTunneling({List<_i29.PageRouteInfo>? children})
      : super(
          WebsiteSplitTunneling.name,
          initialChildren: children,
        );

  static const String name = 'WebsiteSplitTunneling';

  static _i29.PageInfo page = _i29.PageInfo(
    name,
    builder: (data) {
      return const _i28.WebsiteSplitTunneling();
    },
  );
}
