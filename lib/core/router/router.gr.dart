// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:auto_route/auto_route.dart' as _i19;
import 'package:flutter/material.dart' as _i20;
import 'package:lantern/features/account/account.dart' as _i1;
import 'package:lantern/features/account/delete_account.dart' as _i6;
import 'package:lantern/features/auth/add_email.dart' as _i2;
import 'package:lantern/features/auth/choose_payment_method.dart' as _i3;
import 'package:lantern/features/auth/confirm_email.dart' as _i4;
import 'package:lantern/features/auth/create_password.dart' as _i5;
import 'package:lantern/features/home/home.dart' as _i9;
import 'package:lantern/features/language/language.dart' as _i11;
import 'package:lantern/features/logs/logs.dart' as _i12;
import 'package:lantern/features/plans/plans.dart' as _i13;
import 'package:lantern/features/reportIssue/report_issue.dart' as _i14;
import 'package:lantern/features/setting/download_links.dart' as _i7;
import 'package:lantern/features/setting/follow_us.dart' as _i8;
import 'package:lantern/features/setting/invite_friends.dart' as _i10;
import 'package:lantern/features/setting/setting.dart' as _i16;
import 'package:lantern/features/setting/vpn_setting.dart' as _i18;
import 'package:lantern/features/support/support.dart' as _i17;
import 'package:lantern/features/vpn/server_selection.dart' as _i15;

/// generated route for
/// [_i1.Account]
class Account extends _i19.PageRouteInfo<void> {
  const Account({List<_i19.PageRouteInfo>? children})
      : super(
          Account.name,
          initialChildren: children,
        );

  static const String name = 'Account';

  static _i19.PageInfo page = _i19.PageInfo(
    name,
    builder: (data) {
      return const _i1.Account();
    },
  );
}

/// generated route for
/// [_i2.AddEmail]
class AddEmail extends _i19.PageRouteInfo<void> {
  const AddEmail({List<_i19.PageRouteInfo>? children})
      : super(
          AddEmail.name,
          initialChildren: children,
        );

  static const String name = 'AddEmail';

  static _i19.PageInfo page = _i19.PageInfo(
    name,
    builder: (data) {
      return const _i2.AddEmail();
    },
  );
}

/// generated route for
/// [_i3.ChoosePaymentMethod]
class ChoosePaymentMethod extends _i19.PageRouteInfo<void> {
  const ChoosePaymentMethod({List<_i19.PageRouteInfo>? children})
      : super(
          ChoosePaymentMethod.name,
          initialChildren: children,
        );

  static const String name = 'ChoosePaymentMethod';

  static _i19.PageInfo page = _i19.PageInfo(
    name,
    builder: (data) {
      return const _i3.ChoosePaymentMethod();
    },
  );
}

/// generated route for
/// [_i4.ConfirmEmail]
class ConfirmEmail extends _i19.PageRouteInfo<ConfirmEmailArgs> {
  ConfirmEmail({
    _i20.Key? key,
    required String email,
    List<_i19.PageRouteInfo>? children,
  }) : super(
          ConfirmEmail.name,
          args: ConfirmEmailArgs(
            key: key,
            email: email,
          ),
          initialChildren: children,
        );

  static const String name = 'ConfirmEmail';

  static _i19.PageInfo page = _i19.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ConfirmEmailArgs>();
      return _i4.ConfirmEmail(
        key: args.key,
        email: args.email,
      );
    },
  );
}

class ConfirmEmailArgs {
  const ConfirmEmailArgs({
    this.key,
    required this.email,
  });

  final _i20.Key? key;

  final String email;

  @override
  String toString() {
    return 'ConfirmEmailArgs{key: $key, email: $email}';
  }
}

/// generated route for
/// [_i5.CreatePassword]
class CreatePassword extends _i19.PageRouteInfo<CreatePasswordArgs> {
  CreatePassword({
    _i20.Key? key,
    required String email,
    List<_i19.PageRouteInfo>? children,
  }) : super(
          CreatePassword.name,
          args: CreatePasswordArgs(
            key: key,
            email: email,
          ),
          initialChildren: children,
        );

  static const String name = 'CreatePassword';

  static _i19.PageInfo page = _i19.PageInfo(
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

  final _i20.Key? key;

  final String email;

  @override
  String toString() {
    return 'CreatePasswordArgs{key: $key, email: $email}';
  }
}

/// generated route for
/// [_i6.DeleteAccount]
class DeleteAccount extends _i19.PageRouteInfo<void> {
  const DeleteAccount({List<_i19.PageRouteInfo>? children})
      : super(
          DeleteAccount.name,
          initialChildren: children,
        );

  static const String name = 'DeleteAccount';

  static _i19.PageInfo page = _i19.PageInfo(
    name,
    builder: (data) {
      return const _i6.DeleteAccount();
    },
  );
}

/// generated route for
/// [_i7.DownloadLinks]
class DownloadLinks extends _i19.PageRouteInfo<void> {
  const DownloadLinks({List<_i19.PageRouteInfo>? children})
      : super(
          DownloadLinks.name,
          initialChildren: children,
        );

  static const String name = 'DownloadLinks';

  static _i19.PageInfo page = _i19.PageInfo(
    name,
    builder: (data) {
      return const _i7.DownloadLinks();
    },
  );
}

/// generated route for
/// [_i8.FollowUs]
class FollowUs extends _i19.PageRouteInfo<FollowUsArgs> {
  FollowUs({
    _i20.Key? key,
    List<_i19.PageRouteInfo>? children,
  }) : super(
          FollowUs.name,
          args: FollowUsArgs(key: key),
          initialChildren: children,
        );

  static const String name = 'FollowUs';

  static _i19.PageInfo page = _i19.PageInfo(
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

  final _i20.Key? key;

  @override
  String toString() {
    return 'FollowUsArgs{key: $key}';
  }
}

/// generated route for
/// [_i9.Home]
class Home extends _i19.PageRouteInfo<HomeArgs> {
  Home({
    _i20.Key? key,
    List<_i19.PageRouteInfo>? children,
  }) : super(
          Home.name,
          args: HomeArgs(key: key),
          initialChildren: children,
        );

  static const String name = 'Home';

  static _i19.PageInfo page = _i19.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<HomeArgs>(orElse: () => const HomeArgs());
      return _i9.Home(key: args.key);
    },
  );
}

class HomeArgs {
  const HomeArgs({this.key});

  final _i20.Key? key;

  @override
  String toString() {
    return 'HomeArgs{key: $key}';
  }
}

/// generated route for
/// [_i10.InviteFriends]
class InviteFriends extends _i19.PageRouteInfo<void> {
  const InviteFriends({List<_i19.PageRouteInfo>? children})
      : super(
          InviteFriends.name,
          initialChildren: children,
        );

  static const String name = 'InviteFriends';

  static _i19.PageInfo page = _i19.PageInfo(
    name,
    builder: (data) {
      return const _i10.InviteFriends();
    },
  );
}

/// generated route for
/// [_i11.Language]
class Language extends _i19.PageRouteInfo<void> {
  const Language({List<_i19.PageRouteInfo>? children})
      : super(
          Language.name,
          initialChildren: children,
        );

  static const String name = 'Language';

  static _i19.PageInfo page = _i19.PageInfo(
    name,
    builder: (data) {
      return const _i11.Language();
    },
  );
}

/// generated route for
/// [_i12.Logs]
class Logs extends _i19.PageRouteInfo<void> {
  const Logs({List<_i19.PageRouteInfo>? children})
      : super(
          Logs.name,
          initialChildren: children,
        );

  static const String name = 'Logs';

  static _i19.PageInfo page = _i19.PageInfo(
    name,
    builder: (data) {
      return const _i12.Logs();
    },
  );
}

/// generated route for
/// [_i13.Plans]
class Plans extends _i19.PageRouteInfo<void> {
  const Plans({List<_i19.PageRouteInfo>? children})
      : super(
          Plans.name,
          initialChildren: children,
        );

  static const String name = 'Plans';

  static _i19.PageInfo page = _i19.PageInfo(
    name,
    builder: (data) {
      return const _i13.Plans();
    },
  );
}

/// generated route for
/// [_i14.ReportIssue]
class ReportIssue extends _i19.PageRouteInfo<ReportIssueArgs> {
  ReportIssue({
    _i20.Key? key,
    String? description,
    List<_i19.PageRouteInfo>? children,
  }) : super(
          ReportIssue.name,
          args: ReportIssueArgs(
            key: key,
            description: description,
          ),
          initialChildren: children,
        );

  static const String name = 'ReportIssue';

  static _i19.PageInfo page = _i19.PageInfo(
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

  final _i20.Key? key;

  final String? description;

  @override
  String toString() {
    return 'ReportIssueArgs{key: $key, description: $description}';
  }
}

/// generated route for
/// [_i15.ServerSelection]
class ServerSelection extends _i19.PageRouteInfo<void> {
  const ServerSelection({List<_i19.PageRouteInfo>? children})
      : super(
          ServerSelection.name,
          initialChildren: children,
        );

  static const String name = 'ServerSelection';

  static _i19.PageInfo page = _i19.PageInfo(
    name,
    builder: (data) {
      return const _i15.ServerSelection();
    },
  );
}

/// generated route for
/// [_i16.Setting]
class Setting extends _i19.PageRouteInfo<SettingArgs> {
  Setting({
    _i20.Key? key,
    List<_i19.PageRouteInfo>? children,
  }) : super(
          Setting.name,
          args: SettingArgs(key: key),
          initialChildren: children,
        );

  static const String name = 'Setting';

  static _i19.PageInfo page = _i19.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SettingArgs>(orElse: () => const SettingArgs());
      return _i16.Setting(key: args.key);
    },
  );
}

class SettingArgs {
  const SettingArgs({this.key});

  final _i20.Key? key;

  @override
  String toString() {
    return 'SettingArgs{key: $key}';
  }
}

/// generated route for
/// [_i17.Support]
class Support extends _i19.PageRouteInfo<void> {
  const Support({List<_i19.PageRouteInfo>? children})
      : super(
          Support.name,
          initialChildren: children,
        );

  static const String name = 'Support';

  static _i19.PageInfo page = _i19.PageInfo(
    name,
    builder: (data) {
      return const _i17.Support();
    },
  );
}

/// generated route for
/// [_i18.VPNSetting]
class VPNSetting extends _i19.PageRouteInfo<void> {
  const VPNSetting({List<_i19.PageRouteInfo>? children})
      : super(
          VPNSetting.name,
          initialChildren: children,
        );

  static const String name = 'VPNSetting';

  static _i19.PageInfo page = _i19.PageInfo(
    name,
    builder: (data) {
      return const _i18.VPNSetting();
    },
  );
}
