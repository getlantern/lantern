// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:auto_route/auto_route.dart' as _i24;
import 'package:flutter/material.dart' as _i25;
import 'package:lantern/core/common/common.dart' as _i26;
import 'package:lantern/features/account/account.dart' as _i1;
import 'package:lantern/features/account/delete_account.dart' as _i7;
import 'package:lantern/features/auth/activation_code.dart' as _i2;
import 'package:lantern/features/auth/add_email.dart' as _i3;
import 'package:lantern/features/auth/choose_payment_method.dart' as _i4;
import 'package:lantern/features/auth/confirm_email.dart' as _i5;
import 'package:lantern/features/auth/create_password.dart' as _i6;
import 'package:lantern/features/auth/reset_password.dart' as _i16;
import 'package:lantern/features/auth/reset_password_email.dart' as _i17;
import 'package:lantern/features/auth/sign_in_email.dart' as _i20;
import 'package:lantern/features/auth/sign_in_password.dart' as _i21;
import 'package:lantern/features/home/home.dart' as _i10;
import 'package:lantern/features/language/language.dart' as _i12;
import 'package:lantern/features/logs/logs.dart' as _i13;
import 'package:lantern/features/plans/plans.dart' as _i14;
import 'package:lantern/features/reportIssue/report_issue.dart' as _i15;
import 'package:lantern/features/setting/download_links.dart' as _i8;
import 'package:lantern/features/setting/follow_us.dart' as _i9;
import 'package:lantern/features/setting/invite_friends.dart' as _i11;
import 'package:lantern/features/setting/setting.dart' as _i19;
import 'package:lantern/features/setting/vpn_setting.dart' as _i23;
import 'package:lantern/features/support/support.dart' as _i22;
import 'package:lantern/features/vpn/server_selection.dart' as _i18;

/// generated route for
/// [_i1.Account]
class Account extends _i24.PageRouteInfo<void> {
  const Account({List<_i24.PageRouteInfo>? children})
      : super(
          Account.name,
          initialChildren: children,
        );

  static const String name = 'Account';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      return const _i1.Account();
    },
  );
}

/// generated route for
/// [_i2.ActivationCode]
class ActivationCode extends _i24.PageRouteInfo<void> {
  const ActivationCode({List<_i24.PageRouteInfo>? children})
      : super(
          ActivationCode.name,
          initialChildren: children,
        );

  static const String name = 'ActivationCode';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      return const _i2.ActivationCode();
    },
  );
}

/// generated route for
/// [_i3.AddEmail]
class AddEmail extends _i24.PageRouteInfo<AddEmailArgs> {
  AddEmail({
    _i25.Key? key,
    _i26.AuthFlow authFlow = _i26.AuthFlow.signUp,
    List<_i24.PageRouteInfo>? children,
  }) : super(
          AddEmail.name,
          args: AddEmailArgs(
            key: key,
            authFlow: authFlow,
          ),
          initialChildren: children,
        );

  static const String name = 'AddEmail';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      final args =
          data.argsAs<AddEmailArgs>(orElse: () => const AddEmailArgs());
      return _i3.AddEmail(
        key: args.key,
        authFlow: args.authFlow,
      );
    },
  );
}

class AddEmailArgs {
  const AddEmailArgs({
    this.key,
    this.authFlow = _i26.AuthFlow.signUp,
  });

  final _i25.Key? key;

  final _i26.AuthFlow authFlow;

  @override
  String toString() {
    return 'AddEmailArgs{key: $key, authFlow: $authFlow}';
  }
}

/// generated route for
/// [_i4.ChoosePaymentMethod]
class ChoosePaymentMethod extends _i24.PageRouteInfo<void> {
  const ChoosePaymentMethod({List<_i24.PageRouteInfo>? children})
      : super(
          ChoosePaymentMethod.name,
          initialChildren: children,
        );

  static const String name = 'ChoosePaymentMethod';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      return const _i4.ChoosePaymentMethod();
    },
  );
}

/// generated route for
/// [_i5.ConfirmEmail]
class ConfirmEmail extends _i24.PageRouteInfo<ConfirmEmailArgs> {
  ConfirmEmail({
    _i25.Key? key,
    required String email,
    _i26.AuthFlow authFlow = _i26.AuthFlow.signUp,
    List<_i24.PageRouteInfo>? children,
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

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ConfirmEmailArgs>();
      return _i5.ConfirmEmail(
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
    this.authFlow = _i26.AuthFlow.signUp,
  });

  final _i25.Key? key;

  final String email;

  final _i26.AuthFlow authFlow;

  @override
  String toString() {
    return 'ConfirmEmailArgs{key: $key, email: $email, authFlow: $authFlow}';
  }
}

/// generated route for
/// [_i6.CreatePassword]
class CreatePassword extends _i24.PageRouteInfo<CreatePasswordArgs> {
  CreatePassword({
    _i25.Key? key,
    required String email,
    List<_i24.PageRouteInfo>? children,
  }) : super(
          CreatePassword.name,
          args: CreatePasswordArgs(
            key: key,
            email: email,
          ),
          initialChildren: children,
        );

  static const String name = 'CreatePassword';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<CreatePasswordArgs>();
      return _i6.CreatePassword(
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

  final _i25.Key? key;

  final String email;

  @override
  String toString() {
    return 'CreatePasswordArgs{key: $key, email: $email}';
  }
}

/// generated route for
/// [_i7.DeleteAccount]
class DeleteAccount extends _i24.PageRouteInfo<void> {
  const DeleteAccount({List<_i24.PageRouteInfo>? children})
      : super(
          DeleteAccount.name,
          initialChildren: children,
        );

  static const String name = 'DeleteAccount';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      return const _i7.DeleteAccount();
    },
  );
}

/// generated route for
/// [_i8.DownloadLinks]
class DownloadLinks extends _i24.PageRouteInfo<void> {
  const DownloadLinks({List<_i24.PageRouteInfo>? children})
      : super(
          DownloadLinks.name,
          initialChildren: children,
        );

  static const String name = 'DownloadLinks';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      return const _i8.DownloadLinks();
    },
  );
}

/// generated route for
/// [_i9.FollowUs]
class FollowUs extends _i24.PageRouteInfo<FollowUsArgs> {
  FollowUs({
    _i25.Key? key,
    List<_i24.PageRouteInfo>? children,
  }) : super(
          FollowUs.name,
          args: FollowUsArgs(key: key),
          initialChildren: children,
        );

  static const String name = 'FollowUs';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      final args =
          data.argsAs<FollowUsArgs>(orElse: () => const FollowUsArgs());
      return _i9.FollowUs(key: args.key);
    },
  );
}

class FollowUsArgs {
  const FollowUsArgs({this.key});

  final _i25.Key? key;

  @override
  String toString() {
    return 'FollowUsArgs{key: $key}';
  }
}

/// generated route for
/// [_i10.Home]
class Home extends _i24.PageRouteInfo<HomeArgs> {
  Home({
    _i25.Key? key,
    List<_i24.PageRouteInfo>? children,
  }) : super(
          Home.name,
          args: HomeArgs(key: key),
          initialChildren: children,
        );

  static const String name = 'Home';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<HomeArgs>(orElse: () => const HomeArgs());
      return _i10.Home(key: args.key);
    },
  );
}

class HomeArgs {
  const HomeArgs({this.key});

  final _i25.Key? key;

  @override
  String toString() {
    return 'HomeArgs{key: $key}';
  }
}

/// generated route for
/// [_i11.InviteFriends]
class InviteFriends extends _i24.PageRouteInfo<void> {
  const InviteFriends({List<_i24.PageRouteInfo>? children})
      : super(
          InviteFriends.name,
          initialChildren: children,
        );

  static const String name = 'InviteFriends';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      return const _i11.InviteFriends();
    },
  );
}

/// generated route for
/// [_i12.Language]
class Language extends _i24.PageRouteInfo<void> {
  const Language({List<_i24.PageRouteInfo>? children})
      : super(
          Language.name,
          initialChildren: children,
        );

  static const String name = 'Language';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      return const _i12.Language();
    },
  );
}

/// generated route for
/// [_i13.Logs]
class Logs extends _i24.PageRouteInfo<void> {
  const Logs({List<_i24.PageRouteInfo>? children})
      : super(
          Logs.name,
          initialChildren: children,
        );

  static const String name = 'Logs';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      return const _i13.Logs();
    },
  );
}

/// generated route for
/// [_i14.Plans]
class Plans extends _i24.PageRouteInfo<void> {
  const Plans({List<_i24.PageRouteInfo>? children})
      : super(
          Plans.name,
          initialChildren: children,
        );

  static const String name = 'Plans';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      return const _i14.Plans();
    },
  );
}

/// generated route for
/// [_i15.ReportIssue]
class ReportIssue extends _i24.PageRouteInfo<ReportIssueArgs> {
  ReportIssue({
    _i25.Key? key,
    String? description,
    List<_i24.PageRouteInfo>? children,
  }) : super(
          ReportIssue.name,
          args: ReportIssueArgs(
            key: key,
            description: description,
          ),
          initialChildren: children,
        );

  static const String name = 'ReportIssue';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      final args =
          data.argsAs<ReportIssueArgs>(orElse: () => const ReportIssueArgs());
      return _i15.ReportIssue(
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

  final _i25.Key? key;

  final String? description;

  @override
  String toString() {
    return 'ReportIssueArgs{key: $key, description: $description}';
  }
}

/// generated route for
/// [_i16.ResetPassword]
class ResetPassword extends _i24.PageRouteInfo<ResetPasswordArgs> {
  ResetPassword({
    _i25.Key? key,
    required String email,
    List<_i24.PageRouteInfo>? children,
  }) : super(
          ResetPassword.name,
          args: ResetPasswordArgs(
            key: key,
            email: email,
          ),
          initialChildren: children,
        );

  static const String name = 'ResetPassword';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ResetPasswordArgs>();
      return _i16.ResetPassword(
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

  final _i25.Key? key;

  final String email;

  @override
  String toString() {
    return 'ResetPasswordArgs{key: $key, email: $email}';
  }
}

/// generated route for
/// [_i17.ResetPasswordEmail]
class ResetPasswordEmail extends _i24.PageRouteInfo<void> {
  const ResetPasswordEmail({List<_i24.PageRouteInfo>? children})
      : super(
          ResetPasswordEmail.name,
          initialChildren: children,
        );

  static const String name = 'ResetPasswordEmail';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      return const _i17.ResetPasswordEmail();
    },
  );
}

/// generated route for
/// [_i18.ServerSelection]
class ServerSelection extends _i24.PageRouteInfo<void> {
  const ServerSelection({List<_i24.PageRouteInfo>? children})
      : super(
          ServerSelection.name,
          initialChildren: children,
        );

  static const String name = 'ServerSelection';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      return const _i18.ServerSelection();
    },
  );
}

/// generated route for
/// [_i19.Setting]
class Setting extends _i24.PageRouteInfo<SettingArgs> {
  Setting({
    _i25.Key? key,
    List<_i24.PageRouteInfo>? children,
  }) : super(
          Setting.name,
          args: SettingArgs(key: key),
          initialChildren: children,
        );

  static const String name = 'Setting';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SettingArgs>(orElse: () => const SettingArgs());
      return _i19.Setting(key: args.key);
    },
  );
}

class SettingArgs {
  const SettingArgs({this.key});

  final _i25.Key? key;

  @override
  String toString() {
    return 'SettingArgs{key: $key}';
  }
}

/// generated route for
/// [_i20.SignInEmail]
class SignInEmail extends _i24.PageRouteInfo<void> {
  const SignInEmail({List<_i24.PageRouteInfo>? children})
      : super(
          SignInEmail.name,
          initialChildren: children,
        );

  static const String name = 'SignInEmail';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      return const _i20.SignInEmail();
    },
  );
}

/// generated route for
/// [_i21.SignInPassword]
class SignInPassword extends _i24.PageRouteInfo<SignInPasswordArgs> {
  SignInPassword({
    _i25.Key? key,
    required String email,
    List<_i24.PageRouteInfo>? children,
  }) : super(
          SignInPassword.name,
          args: SignInPasswordArgs(
            key: key,
            email: email,
          ),
          initialChildren: children,
        );

  static const String name = 'SignInPassword';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SignInPasswordArgs>();
      return _i21.SignInPassword(
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

  final _i25.Key? key;

  final String email;

  @override
  String toString() {
    return 'SignInPasswordArgs{key: $key, email: $email}';
  }
}

/// generated route for
/// [_i22.Support]
class Support extends _i24.PageRouteInfo<void> {
  const Support({List<_i24.PageRouteInfo>? children})
      : super(
          Support.name,
          initialChildren: children,
        );

  static const String name = 'Support';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      return const _i22.Support();
    },
  );
}

/// generated route for
/// [_i23.VPNSetting]
class VPNSetting extends _i24.PageRouteInfo<void> {
  const VPNSetting({List<_i24.PageRouteInfo>? children})
      : super(
          VPNSetting.name,
          initialChildren: children,
        );

  static const String name = 'VPNSetting';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      return const _i23.VPNSetting();
    },
  );
}
