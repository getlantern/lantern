// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:auto_route/auto_route.dart' as _i15;
import 'package:flutter/material.dart' as _i16;
import 'package:lantern/features/account/account.dart' as _i1;
import 'package:lantern/features/account/delete_account.dart' as _i2;
import 'package:lantern/features/home/home.dart' as _i5;
import 'package:lantern/features/language/language.dart' as _i7;
import 'package:lantern/features/logs/logs.dart' as _i8;
import 'package:lantern/features/reportIssue/plans.dart' as _i9;
import 'package:lantern/features/reportIssue/report_issue.dart' as _i10;
import 'package:lantern/features/setting/download_links.dart' as _i3;
import 'package:lantern/features/setting/follow_us.dart' as _i4;
import 'package:lantern/features/setting/invite_friends.dart' as _i6;
import 'package:lantern/features/setting/setting.dart' as _i12;
import 'package:lantern/features/setting/vpn_setting.dart' as _i14;
import 'package:lantern/features/support/support.dart' as _i13;
import 'package:lantern/features/vpn/server_selection.dart' as _i11;

/// generated route for
/// [_i1.Account]
class Account extends _i15.PageRouteInfo<void> {
  const Account({List<_i15.PageRouteInfo>? children})
      : super(
          Account.name,
          initialChildren: children,
        );

  static const String name = 'Account';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      return const _i1.Account();
    },
  );
}

/// generated route for
/// [_i2.DeleteAccount]
class DeleteAccount extends _i15.PageRouteInfo<void> {
  const DeleteAccount({List<_i15.PageRouteInfo>? children})
      : super(
          DeleteAccount.name,
          initialChildren: children,
        );

  static const String name = 'DeleteAccount';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      return const _i2.DeleteAccount();
    },
  );
}

/// generated route for
/// [_i3.DownloadLinks]
class DownloadLinks extends _i15.PageRouteInfo<void> {
  const DownloadLinks({List<_i15.PageRouteInfo>? children})
      : super(
          DownloadLinks.name,
          initialChildren: children,
        );

  static const String name = 'DownloadLinks';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      return const _i3.DownloadLinks();
    },
  );
}

/// generated route for
/// [_i4.FollowUs]
class FollowUs extends _i15.PageRouteInfo<FollowUsArgs> {
  FollowUs({
    _i16.Key? key,
    List<_i15.PageRouteInfo>? children,
  }) : super(
          FollowUs.name,
          args: FollowUsArgs(key: key),
          initialChildren: children,
        );

  static const String name = 'FollowUs';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      final args =
          data.argsAs<FollowUsArgs>(orElse: () => const FollowUsArgs());
      return _i4.FollowUs(key: args.key);
    },
  );
}

class FollowUsArgs {
  const FollowUsArgs({this.key});

  final _i16.Key? key;

  @override
  String toString() {
    return 'FollowUsArgs{key: $key}';
  }
}

/// generated route for
/// [_i5.Home]
class Home extends _i15.PageRouteInfo<HomeArgs> {
  Home({
    _i16.Key? key,
    List<_i15.PageRouteInfo>? children,
  }) : super(
          Home.name,
          args: HomeArgs(key: key),
          initialChildren: children,
        );

  static const String name = 'Home';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<HomeArgs>(orElse: () => const HomeArgs());
      return _i5.Home(key: args.key);
    },
  );
}

class HomeArgs {
  const HomeArgs({this.key});

  final _i16.Key? key;

  @override
  String toString() {
    return 'HomeArgs{key: $key}';
  }
}

/// generated route for
/// [_i6.InviteFriends]
class InviteFriends extends _i15.PageRouteInfo<void> {
  const InviteFriends({List<_i15.PageRouteInfo>? children})
      : super(
          InviteFriends.name,
          initialChildren: children,
        );

  static const String name = 'InviteFriends';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      return const _i6.InviteFriends();
    },
  );
}

/// generated route for
/// [_i7.Language]
class Language extends _i15.PageRouteInfo<void> {
  const Language({List<_i15.PageRouteInfo>? children})
      : super(
          Language.name,
          initialChildren: children,
        );

  static const String name = 'Language';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      return const _i7.Language();
    },
  );
}

/// generated route for
/// [_i8.Logs]
class Logs extends _i15.PageRouteInfo<void> {
  const Logs({List<_i15.PageRouteInfo>? children})
      : super(
          Logs.name,
          initialChildren: children,
        );

  static const String name = 'Logs';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      return const _i8.Logs();
    },
  );
}

/// generated route for
/// [_i9.Plans]
class Plans extends _i15.PageRouteInfo<void> {
  const Plans({List<_i15.PageRouteInfo>? children})
      : super(
          Plans.name,
          initialChildren: children,
        );

  static const String name = 'Plans';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      return const _i9.Plans();
    },
  );
}

/// generated route for
/// [_i10.ReportIssue]
class ReportIssue extends _i15.PageRouteInfo<ReportIssueArgs> {
  ReportIssue({
    _i16.Key? key,
    String? description,
    List<_i15.PageRouteInfo>? children,
  }) : super(
          ReportIssue.name,
          args: ReportIssueArgs(
            key: key,
            description: description,
          ),
          initialChildren: children,
        );

  static const String name = 'ReportIssue';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      final args =
          data.argsAs<ReportIssueArgs>(orElse: () => const ReportIssueArgs());
      return _i10.ReportIssue(
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

  final _i16.Key? key;

  final String? description;

  @override
  String toString() {
    return 'ReportIssueArgs{key: $key, description: $description}';
  }
}

/// generated route for
/// [_i11.ServerSelection]
class ServerSelection extends _i15.PageRouteInfo<void> {
  const ServerSelection({List<_i15.PageRouteInfo>? children})
      : super(
          ServerSelection.name,
          initialChildren: children,
        );

  static const String name = 'ServerSelection';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      return const _i11.ServerSelection();
    },
  );
}

/// generated route for
/// [_i12.Setting]
class Setting extends _i15.PageRouteInfo<SettingArgs> {
  Setting({
    _i16.Key? key,
    List<_i15.PageRouteInfo>? children,
  }) : super(
          Setting.name,
          args: SettingArgs(key: key),
          initialChildren: children,
        );

  static const String name = 'Setting';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SettingArgs>(orElse: () => const SettingArgs());
      return _i12.Setting(key: args.key);
    },
  );
}

class SettingArgs {
  const SettingArgs({this.key});

  final _i16.Key? key;

  @override
  String toString() {
    return 'SettingArgs{key: $key}';
  }
}

/// generated route for
/// [_i13.Support]
class Support extends _i15.PageRouteInfo<void> {
  const Support({List<_i15.PageRouteInfo>? children})
      : super(
          Support.name,
          initialChildren: children,
        );

  static const String name = 'Support';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      return const _i13.Support();
    },
  );
}

/// generated route for
/// [_i14.VPNSetting]
class VPNSetting extends _i15.PageRouteInfo<void> {
  const VPNSetting({List<_i15.PageRouteInfo>? children})
      : super(
          VPNSetting.name,
          initialChildren: children,
        );

  static const String name = 'VPNSetting';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      return const _i14.VPNSetting();
    },
  );
}
