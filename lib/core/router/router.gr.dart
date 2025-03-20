// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:auto_route/auto_route.dart' as _i17;
import 'package:flutter/material.dart' as _i18;
import 'package:lantern/features/account/account.dart' as _i1;
import 'package:lantern/features/account/delete_account.dart' as _i3;
import 'package:lantern/features/home/home.dart' as _i6;
import 'package:lantern/features/language/language.dart' as _i8;
import 'package:lantern/features/logs/logs.dart' as _i9;
import 'package:lantern/features/reportIssue/report_issue.dart' as _i10;
import 'package:lantern/features/setting/download_links.dart' as _i4;
import 'package:lantern/features/setting/follow_us.dart' as _i5;
import 'package:lantern/features/setting/invite_friends.dart' as _i7;
import 'package:lantern/features/setting/setting.dart' as _i12;
import 'package:lantern/features/setting/vpn_setting.dart' as _i15;
import 'package:lantern/features/split_tunneling/apps_split_tunneling.dart'
    as _i2;
import 'package:lantern/features/split_tunneling/split_tunneling.dart' as _i13;
import 'package:lantern/features/split_tunneling/website_split_tunneling.dart'
    as _i16;
import 'package:lantern/features/support/support.dart' as _i14;
import 'package:lantern/features/vpn/server_selection.dart' as _i11;

/// generated route for
/// [_i1.Account]
class Account extends _i17.PageRouteInfo<void> {
  const Account({List<_i17.PageRouteInfo>? children})
      : super(
          Account.name,
          initialChildren: children,
        );

  static const String name = 'Account';

  static _i17.PageInfo page = _i17.PageInfo(
    name,
    builder: (data) {
      return const _i1.Account();
    },
  );
}

/// generated route for
/// [_i2.AppsSplitTunneling]
class AppsSplitTunneling extends _i17.PageRouteInfo<void> {
  const AppsSplitTunneling({List<_i17.PageRouteInfo>? children})
      : super(
          AppsSplitTunneling.name,
          initialChildren: children,
        );

  static const String name = 'AppsSplitTunneling';

  static _i17.PageInfo page = _i17.PageInfo(
    name,
    builder: (data) {
      return const _i2.AppsSplitTunneling();
    },
  );
}

/// generated route for
/// [_i3.DeleteAccount]
class DeleteAccount extends _i17.PageRouteInfo<void> {
  const DeleteAccount({List<_i17.PageRouteInfo>? children})
      : super(
          DeleteAccount.name,
          initialChildren: children,
        );

  static const String name = 'DeleteAccount';

  static _i17.PageInfo page = _i17.PageInfo(
    name,
    builder: (data) {
      return const _i3.DeleteAccount();
    },
  );
}

/// generated route for
/// [_i4.DownloadLinks]
class DownloadLinks extends _i17.PageRouteInfo<void> {
  const DownloadLinks({List<_i17.PageRouteInfo>? children})
      : super(
          DownloadLinks.name,
          initialChildren: children,
        );

  static const String name = 'DownloadLinks';

  static _i17.PageInfo page = _i17.PageInfo(
    name,
    builder: (data) {
      return const _i4.DownloadLinks();
    },
  );
}

/// generated route for
/// [_i5.FollowUs]
class FollowUs extends _i17.PageRouteInfo<FollowUsArgs> {
  FollowUs({
    _i18.Key? key,
    List<_i17.PageRouteInfo>? children,
  }) : super(
          FollowUs.name,
          args: FollowUsArgs(key: key),
          initialChildren: children,
        );

  static const String name = 'FollowUs';

  static _i17.PageInfo page = _i17.PageInfo(
    name,
    builder: (data) {
      final args =
          data.argsAs<FollowUsArgs>(orElse: () => const FollowUsArgs());
      return _i5.FollowUs(key: args.key);
    },
  );
}

class FollowUsArgs {
  const FollowUsArgs({this.key});

  final _i18.Key? key;

  @override
  String toString() {
    return 'FollowUsArgs{key: $key}';
  }
}

/// generated route for
/// [_i6.Home]
class Home extends _i17.PageRouteInfo<HomeArgs> {
  Home({
    _i18.Key? key,
    List<_i17.PageRouteInfo>? children,
  }) : super(
          Home.name,
          args: HomeArgs(key: key),
          initialChildren: children,
        );

  static const String name = 'Home';

  static _i17.PageInfo page = _i17.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<HomeArgs>(orElse: () => const HomeArgs());
      return _i6.Home(key: args.key);
    },
  );
}

class HomeArgs {
  const HomeArgs({this.key});

  final _i18.Key? key;

  @override
  String toString() {
    return 'HomeArgs{key: $key}';
  }
}

/// generated route for
/// [_i7.InviteFriends]
class InviteFriends extends _i17.PageRouteInfo<void> {
  const InviteFriends({List<_i17.PageRouteInfo>? children})
      : super(
          InviteFriends.name,
          initialChildren: children,
        );

  static const String name = 'InviteFriends';

  static _i17.PageInfo page = _i17.PageInfo(
    name,
    builder: (data) {
      return const _i7.InviteFriends();
    },
  );
}

/// generated route for
/// [_i8.Language]
class Language extends _i17.PageRouteInfo<void> {
  const Language({List<_i17.PageRouteInfo>? children})
      : super(
          Language.name,
          initialChildren: children,
        );

  static const String name = 'Language';

  static _i17.PageInfo page = _i17.PageInfo(
    name,
    builder: (data) {
      return const _i8.Language();
    },
  );
}

/// generated route for
/// [_i9.Logs]
class Logs extends _i17.PageRouteInfo<void> {
  const Logs({List<_i17.PageRouteInfo>? children})
      : super(
          Logs.name,
          initialChildren: children,
        );

  static const String name = 'Logs';

  static _i17.PageInfo page = _i17.PageInfo(
    name,
    builder: (data) {
      return const _i9.Logs();
    },
  );
}

/// generated route for
/// [_i10.ReportIssue]
class ReportIssue extends _i17.PageRouteInfo<ReportIssueArgs> {
  ReportIssue({
    _i18.Key? key,
    String? description,
    List<_i17.PageRouteInfo>? children,
  }) : super(
          ReportIssue.name,
          args: ReportIssueArgs(
            key: key,
            description: description,
          ),
          initialChildren: children,
        );

  static const String name = 'ReportIssue';

  static _i17.PageInfo page = _i17.PageInfo(
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

  final _i18.Key? key;

  final String? description;

  @override
  String toString() {
    return 'ReportIssueArgs{key: $key, description: $description}';
  }
}

/// generated route for
/// [_i11.ServerSelection]
class ServerSelection extends _i17.PageRouteInfo<void> {
  const ServerSelection({List<_i17.PageRouteInfo>? children})
      : super(
          ServerSelection.name,
          initialChildren: children,
        );

  static const String name = 'ServerSelection';

  static _i17.PageInfo page = _i17.PageInfo(
    name,
    builder: (data) {
      return const _i11.ServerSelection();
    },
  );
}

/// generated route for
/// [_i12.Setting]
class Setting extends _i17.PageRouteInfo<SettingArgs> {
  Setting({
    _i18.Key? key,
    List<_i17.PageRouteInfo>? children,
  }) : super(
          Setting.name,
          args: SettingArgs(key: key),
          initialChildren: children,
        );

  static const String name = 'Setting';

  static _i17.PageInfo page = _i17.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SettingArgs>(orElse: () => const SettingArgs());
      return _i12.Setting(key: args.key);
    },
  );
}

class SettingArgs {
  const SettingArgs({this.key});

  final _i18.Key? key;

  @override
  String toString() {
    return 'SettingArgs{key: $key}';
  }
}

/// generated route for
/// [_i13.SplitTunneling]
class SplitTunneling extends _i17.PageRouteInfo<void> {
  const SplitTunneling({List<_i17.PageRouteInfo>? children})
      : super(
          SplitTunneling.name,
          initialChildren: children,
        );

  static const String name = 'SplitTunneling';

  static _i17.PageInfo page = _i17.PageInfo(
    name,
    builder: (data) {
      return const _i13.SplitTunneling();
    },
  );
}

/// generated route for
/// [_i14.Support]
class Support extends _i17.PageRouteInfo<void> {
  const Support({List<_i17.PageRouteInfo>? children})
      : super(
          Support.name,
          initialChildren: children,
        );

  static const String name = 'Support';

  static _i17.PageInfo page = _i17.PageInfo(
    name,
    builder: (data) {
      return const _i14.Support();
    },
  );
}

/// generated route for
/// [_i15.VPNSetting]
class VPNSetting extends _i17.PageRouteInfo<void> {
  const VPNSetting({List<_i17.PageRouteInfo>? children})
      : super(
          VPNSetting.name,
          initialChildren: children,
        );

  static const String name = 'VPNSetting';

  static _i17.PageInfo page = _i17.PageInfo(
    name,
    builder: (data) {
      return const _i15.VPNSetting();
    },
  );
}

/// generated route for
/// [_i16.WebsiteSplitTunneling]
class WebsiteSplitTunneling extends _i17.PageRouteInfo<void> {
  const WebsiteSplitTunneling({List<_i17.PageRouteInfo>? children})
      : super(
          WebsiteSplitTunneling.name,
          initialChildren: children,
        );

  static const String name = 'WebsiteSplitTunneling';

  static _i17.PageInfo page = _i17.PageInfo(
    name,
    builder: (data) {
      return const _i16.WebsiteSplitTunneling();
    },
  );
}
