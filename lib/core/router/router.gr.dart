// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:auto_route/auto_route.dart' as _i23;
import 'package:flutter/material.dart' as _i24;
import 'package:lantern/core/common/common.dart' as _i25;
import 'package:lantern/features/account/account.dart' as _i1;
import 'package:lantern/features/account/delete_account.dart' as _i6;
import 'package:lantern/features/auth/add_email.dart' as _i2;
import 'package:lantern/features/auth/choose_payment_method.dart' as _i3;
import 'package:lantern/features/auth/confirm_email.dart' as _i4;
import 'package:lantern/features/auth/create_password.dart' as _i5;
import 'package:lantern/features/auth/reset_password.dart' as _i15;
import 'package:lantern/features/auth/reset_password_email.dart' as _i16;
import 'package:lantern/features/auth/sign_in_email.dart' as _i19;
import 'package:lantern/features/auth/sign_in_password.dart' as _i20;
import 'package:lantern/features/home/home.dart' as _i9;
import 'package:lantern/features/language/language.dart' as _i11;
import 'package:lantern/features/logs/logs.dart' as _i12;
import 'package:lantern/features/plans/plans.dart' as _i13;
import 'package:lantern/features/reportIssue/report_issue.dart' as _i14;
import 'package:lantern/features/setting/download_links.dart' as _i7;
import 'package:lantern/features/setting/follow_us.dart' as _i8;
import 'package:lantern/features/setting/invite_friends.dart' as _i10;
import 'package:lantern/features/setting/setting.dart' as _i18;
import 'package:lantern/features/setting/vpn_setting.dart' as _i22;
import 'package:lantern/features/support/support.dart' as _i21;
import 'package:lantern/features/vpn/server_selection.dart' as _i17;

/// generated route for
/// [_i1.Account]
class Account extends _i23.PageRouteInfo<void> {
  const Account({List<_i23.PageRouteInfo>? children})
      : super(
          Account.name,
          initialChildren: children,
        );

  static const String name = 'Account';

  static _i23.PageInfo page = _i23.PageInfo(
    name,
    builder: (data) {
      return const _i1.Account();
    },
  );
}

/// generated route for
/// [_i2.AddEmail]
class AddEmail extends _i23.PageRouteInfo<void> {
  const AddEmail({List<_i23.PageRouteInfo>? children})
      : super(
          AddEmail.name,
          initialChildren: children,
        );

  static const String name = 'AddEmail';

  static _i23.PageInfo page = _i23.PageInfo(
    name,
    builder: (data) {
      return const _i2.AddEmail();
    },
  );
}

/// generated route for
/// [_i3.ChoosePaymentMethod]
class ChoosePaymentMethod extends _i23.PageRouteInfo<void> {
  const ChoosePaymentMethod({List<_i23.PageRouteInfo>? children})
      : super(
          ChoosePaymentMethod.name,
          initialChildren: children,
        );

  static const String name = 'ChoosePaymentMethod';

  static _i23.PageInfo page = _i23.PageInfo(
    name,
    builder: (data) {
      return const _i3.ChoosePaymentMethod();
    },
  );
}

/// generated route for
/// [_i4.ConfirmEmail]
class ConfirmEmail extends _i23.PageRouteInfo<ConfirmEmailArgs> {
  ConfirmEmail({
    _i24.Key? key,
    required String email,
    _i25.AuthFlow authFlow = _i25.AuthFlow.signUp,
    List<_i23.PageRouteInfo>? children,
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

  static _i23.PageInfo page = _i23.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ConfirmEmailArgs>();
      return _i4.ConfirmEmail(
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
    this.authFlow = _i25.AuthFlow.signUp,
  });

  final _i24.Key? key;

  final String email;

  final _i25.AuthFlow authFlow;

  @override
  String toString() {
    return 'ConfirmEmailArgs{key: $key, email: $email, authFlow: $authFlow}';
  }
}

/// generated route for
/// [_i5.CreatePassword]
class CreatePassword extends _i23.PageRouteInfo<CreatePasswordArgs> {
  CreatePassword({
    _i24.Key? key,
    required String email,
    List<_i23.PageRouteInfo>? children,
  }) : super(
          CreatePassword.name,
          args: CreatePasswordArgs(
            key: key,
            email: email,
          ),
          initialChildren: children,
        );

  static const String name = 'CreatePassword';

  static _i23.PageInfo page = _i23.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<CreatePasswordArgs>();
      return _i5.CreatePassword(
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

  final _i24.Key? key;

  final String email;

  @override
  String toString() {
    return 'CreatePasswordArgs{key: $key, email: $email}';
  }
}

/// generated route for
/// [_i6.DeleteAccount]
class DeleteAccount extends _i23.PageRouteInfo<void> {
  const DeleteAccount({List<_i23.PageRouteInfo>? children})
      : super(
          DeleteAccount.name,
          initialChildren: children,
        );

  static const String name = 'DeleteAccount';

  static _i23.PageInfo page = _i23.PageInfo(
    name,
    builder: (data) {
      return const _i6.DeleteAccount();
    },
  );
}

/// generated route for
/// [_i7.DownloadLinks]
class DownloadLinks extends _i23.PageRouteInfo<void> {
  const DownloadLinks({List<_i23.PageRouteInfo>? children})
      : super(
          DownloadLinks.name,
          initialChildren: children,
        );

  static const String name = 'DownloadLinks';

  static _i23.PageInfo page = _i23.PageInfo(
    name,
    builder: (data) {
      return const _i7.DownloadLinks();
    },
  );
}

/// generated route for
/// [_i8.FollowUs]
class FollowUs extends _i23.PageRouteInfo<FollowUsArgs> {
  FollowUs({
    _i24.Key? key,
    List<_i23.PageRouteInfo>? children,
  }) : super(
          FollowUs.name,
          args: FollowUsArgs(key: key),
          initialChildren: children,
        );

  static const String name = 'FollowUs';

  static _i23.PageInfo page = _i23.PageInfo(
    name,
    builder: (data) {
      final args =
          data.argsAs<FollowUsArgs>(orElse: () => const FollowUsArgs());
      return _i8.FollowUs(key: args.key);
    },
  );
}

class FollowUsArgs {
  const FollowUsArgs({this.key});

  final _i24.Key? key;

  @override
  String toString() {
    return 'FollowUsArgs{key: $key}';
  }
}

/// generated route for
/// [_i9.Home]
class Home extends _i23.PageRouteInfo<HomeArgs> {
  Home({
    _i24.Key? key,
    List<_i23.PageRouteInfo>? children,
  }) : super(
          Home.name,
          args: HomeArgs(key: key),
          initialChildren: children,
        );

  static const String name = 'Home';

  static _i23.PageInfo page = _i23.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<HomeArgs>(orElse: () => const HomeArgs());
      return _i9.Home(key: args.key);
    },
  );
}

class HomeArgs {
  const HomeArgs({this.key});

  final _i24.Key? key;

  @override
  String toString() {
    return 'HomeArgs{key: $key}';
  }
}

/// generated route for
/// [_i10.InviteFriends]
class InviteFriends extends _i23.PageRouteInfo<void> {
  const InviteFriends({List<_i23.PageRouteInfo>? children})
      : super(
          InviteFriends.name,
          initialChildren: children,
        );

  static const String name = 'InviteFriends';

  static _i23.PageInfo page = _i23.PageInfo(
    name,
    builder: (data) {
      return const _i10.InviteFriends();
    },
  );
}

/// generated route for
/// [_i11.Language]
class Language extends _i23.PageRouteInfo<void> {
  const Language({List<_i23.PageRouteInfo>? children})
      : super(
          Language.name,
          initialChildren: children,
        );

  static const String name = 'Language';

  static _i23.PageInfo page = _i23.PageInfo(
    name,
    builder: (data) {
      return const _i11.Language();
    },
  );
}

/// generated route for
/// [_i12.Logs]
class Logs extends _i23.PageRouteInfo<void> {
  const Logs({List<_i23.PageRouteInfo>? children})
      : super(
          Logs.name,
          initialChildren: children,
        );

  static const String name = 'Logs';

  static _i23.PageInfo page = _i23.PageInfo(
    name,
    builder: (data) {
      return const _i12.Logs();
    },
  );
}

/// generated route for
/// [_i13.Plans]
class Plans extends _i23.PageRouteInfo<void> {
  const Plans({List<_i23.PageRouteInfo>? children})
      : super(
          Plans.name,
          initialChildren: children,
        );

  static const String name = 'Plans';

  static _i23.PageInfo page = _i23.PageInfo(
    name,
    builder: (data) {
      return const _i13.Plans();
    },
  );
}

/// generated route for
/// [_i14.ReportIssue]
class ReportIssue extends _i23.PageRouteInfo<ReportIssueArgs> {
  ReportIssue({
    _i24.Key? key,
    String? description,
    List<_i23.PageRouteInfo>? children,
  }) : super(
          ReportIssue.name,
          args: ReportIssueArgs(
            key: key,
            description: description,
          ),
          initialChildren: children,
        );

  static const String name = 'ReportIssue';

  static _i23.PageInfo page = _i23.PageInfo(
    name,
    builder: (data) {
      final args =
          data.argsAs<ReportIssueArgs>(orElse: () => const ReportIssueArgs());
      return _i14.ReportIssue(
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

  final _i24.Key? key;

  final String? description;

  @override
  String toString() {
    return 'ReportIssueArgs{key: $key, description: $description}';
  }
}

/// generated route for
/// [_i15.ResetPassword]
class ResetPassword extends _i23.PageRouteInfo<ResetPasswordArgs> {
  ResetPassword({
    _i24.Key? key,
    required String email,
    List<_i23.PageRouteInfo>? children,
  }) : super(
          ResetPassword.name,
          args: ResetPasswordArgs(
            key: key,
            email: email,
          ),
          initialChildren: children,
        );

  static const String name = 'ResetPassword';

  static _i23.PageInfo page = _i23.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ResetPasswordArgs>();
      return _i15.ResetPassword(
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

  final _i24.Key? key;

  final String email;

  @override
  String toString() {
    return 'ResetPasswordArgs{key: $key, email: $email}';
  }
}

/// generated route for
/// [_i16.ResetPasswordEmail]
class ResetPasswordEmail extends _i23.PageRouteInfo<void> {
  const ResetPasswordEmail({List<_i23.PageRouteInfo>? children})
      : super(
          ResetPasswordEmail.name,
          initialChildren: children,
        );

  static const String name = 'ResetPasswordEmail';

  static _i23.PageInfo page = _i23.PageInfo(
    name,
    builder: (data) {
      return const _i16.ResetPasswordEmail();
    },
  );
}

/// generated route for
/// [_i17.ServerSelection]
class ServerSelection extends _i23.PageRouteInfo<void> {
  const ServerSelection({List<_i23.PageRouteInfo>? children})
      : super(
          ServerSelection.name,
          initialChildren: children,
        );

  static const String name = 'ServerSelection';

  static _i23.PageInfo page = _i23.PageInfo(
    name,
    builder: (data) {
      return const _i17.ServerSelection();
    },
  );
}

/// generated route for
/// [_i18.Setting]
class Setting extends _i23.PageRouteInfo<SettingArgs> {
  Setting({
    _i24.Key? key,
    List<_i23.PageRouteInfo>? children,
  }) : super(
          Setting.name,
          args: SettingArgs(key: key),
          initialChildren: children,
        );

  static const String name = 'Setting';

  static _i23.PageInfo page = _i23.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SettingArgs>(orElse: () => const SettingArgs());
      return _i18.Setting(key: args.key);
    },
  );
}

class SettingArgs {
  const SettingArgs({this.key});

  final _i24.Key? key;

  @override
  String toString() {
    return 'SettingArgs{key: $key}';
  }
}

/// generated route for
/// [_i19.SignInEmail]
class SignInEmail extends _i23.PageRouteInfo<void> {
  const SignInEmail({List<_i23.PageRouteInfo>? children})
      : super(
          SignInEmail.name,
          initialChildren: children,
        );

  static const String name = 'SignInEmail';

  static _i23.PageInfo page = _i23.PageInfo(
    name,
    builder: (data) {
      return const _i19.SignInEmail();
    },
  );
}

/// generated route for
/// [_i20.SignInPassword]
class SignInPassword extends _i23.PageRouteInfo<SignInPasswordArgs> {
  SignInPassword({
    _i24.Key? key,
    required String email,
    List<_i23.PageRouteInfo>? children,
  }) : super(
          SignInPassword.name,
          args: SignInPasswordArgs(
            key: key,
            email: email,
          ),
          initialChildren: children,
        );

  static const String name = 'SignInPassword';

  static _i23.PageInfo page = _i23.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SignInPasswordArgs>();
      return _i20.SignInPassword(
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

  final _i24.Key? key;

  final String email;

  @override
  String toString() {
    return 'SignInPasswordArgs{key: $key, email: $email}';
  }
}

/// generated route for
/// [_i21.Support]
class Support extends _i23.PageRouteInfo<void> {
  const Support({List<_i23.PageRouteInfo>? children})
      : super(
          Support.name,
          initialChildren: children,
        );

  static const String name = 'Support';

  static _i23.PageInfo page = _i23.PageInfo(
    name,
    builder: (data) {
      return const _i21.Support();
    },
  );
}

/// generated route for
/// [_i22.VPNSetting]
class VPNSetting extends _i23.PageRouteInfo<void> {
  const VPNSetting({List<_i23.PageRouteInfo>? children})
      : super(
          VPNSetting.name,
          initialChildren: children,
        );

  static const String name = 'VPNSetting';

  static _i23.PageInfo page = _i23.PageInfo(
    name,
    builder: (data) {
      return const _i22.VPNSetting();
    },
  );
}
