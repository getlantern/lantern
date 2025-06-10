// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:auto_route/auto_route.dart' as _i30;
import 'package:flutter/material.dart' as _i31;
import 'package:lantern/core/common/common.dart' as _i32;
import 'package:lantern/core/widgets/app_webview.dart' as _i4;
import 'package:lantern/features/account/account.dart' as _i1;
import 'package:lantern/features/account/delete_account.dart' as _i9;
import 'package:lantern/features/auth/activation_code.dart' as _i2;
import 'package:lantern/features/auth/add_email.dart' as _i3;
import 'package:lantern/features/auth/choose_payment_method.dart' as _i6;
import 'package:lantern/features/auth/confirm_email.dart' as _i7;
import 'package:lantern/features/auth/create_password.dart' as _i8;
import 'package:lantern/features/auth/reset_password.dart' as _i19;
import 'package:lantern/features/auth/reset_password_email.dart' as _i20;
import 'package:lantern/features/auth/sign_in_email.dart' as _i23;
import 'package:lantern/features/auth/sign_in_password.dart' as _i24;
import 'package:lantern/features/home/home.dart' as _i12;
import 'package:lantern/features/language/language.dart' as _i14;
import 'package:lantern/features/logs/logs.dart' as _i15;
import 'package:lantern/features/plans/plans.dart' as _i16;
import 'package:lantern/features/private_server/private_server_setup.dart'
    as _i17;
import 'package:lantern/features/reportIssue/report_issue.dart' as _i18;
import 'package:lantern/features/setting/download_links.dart' as _i10;
import 'package:lantern/features/setting/follow_us.dart' as _i11;
import 'package:lantern/features/setting/invite_friends.dart' as _i13;
import 'package:lantern/features/setting/setting.dart' as _i22;
import 'package:lantern/features/setting/vpn_setting.dart' as _i28;
import 'package:lantern/features/split_tunneling/apps_split_tunneling.dart'
    as _i5;
import 'package:lantern/features/split_tunneling/split_tunneling.dart' as _i25;
import 'package:lantern/features/split_tunneling/split_tunneling_info.dart'
    as _i26;
import 'package:lantern/features/split_tunneling/website_split_tunneling.dart'
    as _i29;
import 'package:lantern/features/support/support.dart' as _i27;
import 'package:lantern/features/vpn/server_selection.dart' as _i21;

/// generated route for
/// [_i1.Account]
class Account extends _i30.PageRouteInfo<void> {
  const Account({List<_i30.PageRouteInfo>? children})
      : super(Account.name, initialChildren: children);

  static const String name = 'Account';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return const _i1.Account();
    },
  );
}

/// generated route for
/// [_i2.ActivationCode]
class ActivationCode extends _i30.PageRouteInfo<ActivationCodeArgs> {
  ActivationCode({
    _i31.Key? key,
    required String email,
    required String code,
    List<_i30.PageRouteInfo>? children,
  }) : super(
          ActivationCode.name,
          args: ActivationCodeArgs(key: key, email: email, code: code),
          initialChildren: children,
        );

  static const String name = 'ActivationCode';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ActivationCodeArgs>();
      return _i2.ActivationCode(
        key: args.key,
        email: args.email,
        code: args.code,
      );
    },
  );
}

class ActivationCodeArgs {
  const ActivationCodeArgs({this.key, required this.email, required this.code});

  final _i31.Key? key;

  final String email;

  final String code;

  @override
  String toString() {
    return 'ActivationCodeArgs{key: $key, email: $email, code: $code}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ActivationCodeArgs) return false;
    return key == other.key && email == other.email && code == other.code;
  }

  @override
  int get hashCode => key.hashCode ^ email.hashCode ^ code.hashCode;
}

/// generated route for
/// [_i3.AddEmail]
class AddEmail extends _i30.PageRouteInfo<AddEmailArgs> {
  AddEmail({
    _i31.Key? key,
    _i32.AuthFlow authFlow = _i32.AuthFlow.signUp,
    List<_i30.PageRouteInfo>? children,
  }) : super(
          AddEmail.name,
          args: AddEmailArgs(key: key, authFlow: authFlow),
          initialChildren: children,
        );

  static const String name = 'AddEmail';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<AddEmailArgs>(
        orElse: () => const AddEmailArgs(),
      );
      return _i3.AddEmail(key: args.key, authFlow: args.authFlow);
    },
  );
}

class AddEmailArgs {
  const AddEmailArgs({this.key, this.authFlow = _i32.AuthFlow.signUp});

  final _i31.Key? key;

  final _i32.AuthFlow authFlow;

  @override
  String toString() {
    return 'AddEmailArgs{key: $key, authFlow: $authFlow}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AddEmailArgs) return false;
    return key == other.key && authFlow == other.authFlow;
  }

  @override
  int get hashCode => key.hashCode ^ authFlow.hashCode;
}

/// generated route for
/// [_i4.AppWebView]
class AppWebview extends _i30.PageRouteInfo<AppWebviewArgs> {
  AppWebview({
    _i31.Key? key,
    required String title,
    required String url,
    List<_i30.PageRouteInfo>? children,
  }) : super(
          AppWebview.name,
          args: AppWebviewArgs(key: key, title: title, url: url),
          initialChildren: children,
        );

  static const String name = 'AppWebview';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<AppWebviewArgs>();
      return _i4.AppWebView(key: args.key, title: args.title, url: args.url);
    },
  );
}

class AppWebviewArgs {
  const AppWebviewArgs({this.key, required this.title, required this.url});

  final _i31.Key? key;

  final String title;

  final String url;

  @override
  String toString() {
    return 'AppWebviewArgs{key: $key, title: $title, url: $url}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AppWebviewArgs) return false;
    return key == other.key && title == other.title && url == other.url;
  }

  @override
  int get hashCode => key.hashCode ^ title.hashCode ^ url.hashCode;
}

/// generated route for
/// [_i5.AppsSplitTunneling]
class AppsSplitTunneling extends _i30.PageRouteInfo<void> {
  const AppsSplitTunneling({List<_i30.PageRouteInfo>? children})
      : super(AppsSplitTunneling.name, initialChildren: children);

  static const String name = 'AppsSplitTunneling';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return const _i5.AppsSplitTunneling();
    },
  );
}

/// generated route for
/// [_i6.ChoosePaymentMethod]
class ChoosePaymentMethod extends _i30.PageRouteInfo<ChoosePaymentMethodArgs> {
  ChoosePaymentMethod({
    _i31.Key? key,
    required String email,
    String? code,
    required _i32.AuthFlow authFlow,
    List<_i30.PageRouteInfo>? children,
  }) : super(
          ChoosePaymentMethod.name,
          args: ChoosePaymentMethodArgs(
            key: key,
            email: email,
            code: code,
            authFlow: authFlow,
          ),
          initialChildren: children,
        );

  static const String name = 'ChoosePaymentMethod';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ChoosePaymentMethodArgs>();
      return _i6.ChoosePaymentMethod(
        key: args.key,
        email: args.email,
        code: args.code,
        authFlow: args.authFlow,
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
  });

  final _i31.Key? key;

  final String email;

  final String? code;

  final _i32.AuthFlow authFlow;

  @override
  String toString() {
    return 'ChoosePaymentMethodArgs{key: $key, email: $email, code: $code, authFlow: $authFlow}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ChoosePaymentMethodArgs) return false;
    return key == other.key &&
        email == other.email &&
        code == other.code &&
        authFlow == other.authFlow;
  }

  @override
  int get hashCode =>
      key.hashCode ^ email.hashCode ^ code.hashCode ^ authFlow.hashCode;
}

/// generated route for
/// [_i7.ConfirmEmail]
class ConfirmEmail extends _i30.PageRouteInfo<ConfirmEmailArgs> {
  ConfirmEmail({
    _i31.Key? key,
    required String email,
    _i32.AuthFlow authFlow = _i32.AuthFlow.signUp,
    List<_i30.PageRouteInfo>? children,
  }) : super(
          ConfirmEmail.name,
          args: ConfirmEmailArgs(key: key, email: email, authFlow: authFlow),
          initialChildren: children,
        );

  static const String name = 'ConfirmEmail';

  static _i30.PageInfo page = _i30.PageInfo(
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
    this.authFlow = _i32.AuthFlow.signUp,
  });

  final _i31.Key? key;

  final String email;

  final _i32.AuthFlow authFlow;

  @override
  String toString() {
    return 'ConfirmEmailArgs{key: $key, email: $email, authFlow: $authFlow}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ConfirmEmailArgs) return false;
    return key == other.key &&
        email == other.email &&
        authFlow == other.authFlow;
  }

  @override
  int get hashCode => key.hashCode ^ email.hashCode ^ authFlow.hashCode;
}

/// generated route for
/// [_i8.CreatePassword]
class CreatePassword extends _i30.PageRouteInfo<CreatePasswordArgs> {
  CreatePassword({
    _i31.Key? key,
    required String email,
    required _i32.AuthFlow authFlow,
    required String code,
    List<_i30.PageRouteInfo>? children,
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

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<CreatePasswordArgs>();
      return _i8.CreatePassword(
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

  final _i31.Key? key;

  final String email;

  final _i32.AuthFlow authFlow;

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
/// [_i9.DeleteAccount]
class DeleteAccount extends _i30.PageRouteInfo<void> {
  const DeleteAccount({List<_i30.PageRouteInfo>? children})
      : super(DeleteAccount.name, initialChildren: children);

  static const String name = 'DeleteAccount';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return const _i9.DeleteAccount();
    },
  );
}

/// generated route for
/// [_i10.DownloadLinks]
class DownloadLinks extends _i30.PageRouteInfo<void> {
  const DownloadLinks({List<_i30.PageRouteInfo>? children})
      : super(DownloadLinks.name, initialChildren: children);

  static const String name = 'DownloadLinks';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return const _i10.DownloadLinks();
    },
  );
}

/// generated route for
/// [_i11.FollowUs]
class FollowUs extends _i30.PageRouteInfo<FollowUsArgs> {
  FollowUs({_i31.Key? key, List<_i30.PageRouteInfo>? children})
      : super(
          FollowUs.name,
          args: FollowUsArgs(key: key),
          initialChildren: children,
        );

  static const String name = 'FollowUs';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<FollowUsArgs>(
        orElse: () => const FollowUsArgs(),
      );
      return _i11.FollowUs(key: args.key);
    },
  );
}

class FollowUsArgs {
  const FollowUsArgs({this.key});

  final _i31.Key? key;

  @override
  String toString() {
    return 'FollowUsArgs{key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FollowUsArgs) return false;
    return key == other.key;
  }

  @override
  int get hashCode => key.hashCode;
}

/// generated route for
/// [_i12.Home]
class Home extends _i30.PageRouteInfo<HomeArgs> {
  Home({_i31.Key? key, List<_i30.PageRouteInfo>? children})
      : super(
          Home.name,
          args: HomeArgs(key: key),
          initialChildren: children,
        );

  static const String name = 'Home';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<HomeArgs>(orElse: () => const HomeArgs());
      return _i12.Home(key: args.key);
    },
  );
}

class HomeArgs {
  const HomeArgs({this.key});

  final _i31.Key? key;

  @override
  String toString() {
    return 'HomeArgs{key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! HomeArgs) return false;
    return key == other.key;
  }

  @override
  int get hashCode => key.hashCode;
}

/// generated route for
/// [_i13.InviteFriends]
class InviteFriends extends _i30.PageRouteInfo<void> {
  const InviteFriends({List<_i30.PageRouteInfo>? children})
      : super(InviteFriends.name, initialChildren: children);

  static const String name = 'InviteFriends';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return const _i13.InviteFriends();
    },
  );
}

/// generated route for
/// [_i14.Language]
class Language extends _i30.PageRouteInfo<void> {
  const Language({List<_i30.PageRouteInfo>? children})
      : super(Language.name, initialChildren: children);

  static const String name = 'Language';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return const _i14.Language();
    },
  );
}

/// generated route for
/// [_i15.Logs]
class Logs extends _i30.PageRouteInfo<void> {
  const Logs({List<_i30.PageRouteInfo>? children})
      : super(Logs.name, initialChildren: children);

  static const String name = 'Logs';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return const _i15.Logs();
    },
  );
}

/// generated route for
/// [_i16.Plans]
class Plans extends _i30.PageRouteInfo<void> {
  const Plans({List<_i30.PageRouteInfo>? children})
      : super(Plans.name, initialChildren: children);

  static const String name = 'Plans';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return const _i16.Plans();
    },
  );
}

/// generated route for
/// [_i17.PrivateServerSetup]
class PrivateServerSetup extends _i30.PageRouteInfo<void> {
  const PrivateServerSetup({List<_i30.PageRouteInfo>? children})
      : super(PrivateServerSetup.name, initialChildren: children);

  static const String name = 'PrivateServerSetup';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return const _i17.PrivateServerSetup();
    },
  );
}

/// generated route for
/// [_i18.ReportIssue]
class ReportIssue extends _i30.PageRouteInfo<ReportIssueArgs> {
  ReportIssue({
    _i31.Key? key,
    String? description,
    List<_i30.PageRouteInfo>? children,
  }) : super(
          ReportIssue.name,
          args: ReportIssueArgs(key: key, description: description),
          initialChildren: children,
        );

  static const String name = 'ReportIssue';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ReportIssueArgs>(
        orElse: () => const ReportIssueArgs(),
      );
      return _i18.ReportIssue(key: args.key, description: args.description);
    },
  );
}

class ReportIssueArgs {
  const ReportIssueArgs({this.key, this.description});

  final _i31.Key? key;

  final String? description;

  @override
  String toString() {
    return 'ReportIssueArgs{key: $key, description: $description}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ReportIssueArgs) return false;
    return key == other.key && description == other.description;
  }

  @override
  int get hashCode => key.hashCode ^ description.hashCode;
}

/// generated route for
/// [_i19.ResetPassword]
class ResetPassword extends _i30.PageRouteInfo<ResetPasswordArgs> {
  ResetPassword({
    _i31.Key? key,
    required String email,
    required String code,
    List<_i30.PageRouteInfo>? children,
  }) : super(
          ResetPassword.name,
          args: ResetPasswordArgs(key: key, email: email, code: code),
          initialChildren: children,
        );

  static const String name = 'ResetPassword';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ResetPasswordArgs>();
      return _i19.ResetPassword(
        key: args.key,
        email: args.email,
        code: args.code,
      );
    },
  );
}

class ResetPasswordArgs {
  const ResetPasswordArgs({this.key, required this.email, required this.code});

  final _i31.Key? key;

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
/// [_i20.ResetPasswordEmail]
class ResetPasswordEmail extends _i30.PageRouteInfo<ResetPasswordEmailArgs> {
  ResetPasswordEmail({
    _i31.Key? key,
    String? email,
    List<_i30.PageRouteInfo>? children,
  }) : super(
          ResetPasswordEmail.name,
          args: ResetPasswordEmailArgs(key: key, email: email),
          initialChildren: children,
        );

  static const String name = 'ResetPasswordEmail';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ResetPasswordEmailArgs>(
        orElse: () => const ResetPasswordEmailArgs(),
      );
      return _i20.ResetPasswordEmail(key: args.key, email: args.email);
    },
  );
}

class ResetPasswordEmailArgs {
  const ResetPasswordEmailArgs({this.key, this.email});

  final _i31.Key? key;

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
/// [_i21.ServerSelection]
class ServerSelection extends _i30.PageRouteInfo<void> {
  const ServerSelection({List<_i30.PageRouteInfo>? children})
      : super(ServerSelection.name, initialChildren: children);

  static const String name = 'ServerSelection';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return const _i21.ServerSelection();
    },
  );
}

/// generated route for
/// [_i22.Setting]
class Setting extends _i30.PageRouteInfo<void> {
  const Setting({List<_i30.PageRouteInfo>? children})
      : super(Setting.name, initialChildren: children);

  static const String name = 'Setting';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return const _i22.Setting();
    },
  );
}

/// generated route for
/// [_i23.SignInEmail]
class SignInEmail extends _i30.PageRouteInfo<void> {
  const SignInEmail({List<_i30.PageRouteInfo>? children})
      : super(SignInEmail.name, initialChildren: children);

  static const String name = 'SignInEmail';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return const _i23.SignInEmail();
    },
  );
}

/// generated route for
/// [_i24.SignInPassword]
class SignInPassword extends _i30.PageRouteInfo<SignInPasswordArgs> {
  SignInPassword({
    _i31.Key? key,
    required String email,
    List<_i30.PageRouteInfo>? children,
  }) : super(
          SignInPassword.name,
          args: SignInPasswordArgs(key: key, email: email),
          initialChildren: children,
        );

  static const String name = 'SignInPassword';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SignInPasswordArgs>();
      return _i24.SignInPassword(key: args.key, email: args.email);
    },
  );
}

class SignInPasswordArgs {
  const SignInPasswordArgs({this.key, required this.email});

  final _i31.Key? key;

  final String email;

  @override
  String toString() {
    return 'SignInPasswordArgs{key: $key, email: $email}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SignInPasswordArgs) return false;
    return key == other.key && email == other.email;
  }

  @override
  int get hashCode => key.hashCode ^ email.hashCode;
}

/// generated route for
/// [_i25.SplitTunneling]
class SplitTunneling extends _i30.PageRouteInfo<void> {
  const SplitTunneling({List<_i30.PageRouteInfo>? children})
      : super(SplitTunneling.name, initialChildren: children);

  static const String name = 'SplitTunneling';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return const _i25.SplitTunneling();
    },
  );
}

/// generated route for
/// [_i26.SplitTunnelingInfo]
class SplitTunnelingInfo extends _i30.PageRouteInfo<void> {
  const SplitTunnelingInfo({List<_i30.PageRouteInfo>? children})
      : super(SplitTunnelingInfo.name, initialChildren: children);

  static const String name = 'SplitTunnelingInfo';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return const _i26.SplitTunnelingInfo();
    },
  );
}

/// generated route for
/// [_i27.Support]
class Support extends _i30.PageRouteInfo<void> {
  const Support({List<_i30.PageRouteInfo>? children})
      : super(Support.name, initialChildren: children);

  static const String name = 'Support';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return const _i27.Support();
    },
  );
}

/// generated route for
/// [_i28.VPNSetting]
class VPNSetting extends _i30.PageRouteInfo<void> {
  const VPNSetting({List<_i30.PageRouteInfo>? children})
      : super(VPNSetting.name, initialChildren: children);

  static const String name = 'VPNSetting';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return const _i28.VPNSetting();
    },
  );
}

/// generated route for
/// [_i29.WebsiteSplitTunneling]
class WebsiteSplitTunneling extends _i30.PageRouteInfo<void> {
  const WebsiteSplitTunneling({List<_i30.PageRouteInfo>? children})
      : super(WebsiteSplitTunneling.name, initialChildren: children);

  static const String name = 'WebsiteSplitTunneling';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return const _i29.WebsiteSplitTunneling();
    },
  );
}
