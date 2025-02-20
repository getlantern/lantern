// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:auto_route/auto_route.dart' as _i6;
import 'package:lantern/features/home/home.dart' as _i1;
import 'package:lantern/features/home/new_home.dart' as _i3;
import 'package:lantern/features/language/language.dart' as _i2;
import 'package:lantern/features/reportIssue/report_issue.dart' as _i4;
import 'package:lantern/features/setting/setting.dart' as _i5;

/// generated route for
/// [_i1.HomePage]
class Home extends _i6.PageRouteInfo<void> {
  const Home({List<_i6.PageRouteInfo>? children})
      : super(
          Home.name,
          initialChildren: children,
        );

  static const String name = 'Home';

  static _i6.PageInfo page = _i6.PageInfo(
    name,
    builder: (data) {
      return const _i1.HomePage();
    },
  );
}

/// generated route for
/// [_i2.Language]
class Language extends _i6.PageRouteInfo<void> {
  const Language({List<_i6.PageRouteInfo>? children})
      : super(
          Language.name,
          initialChildren: children,
        );

  static const String name = 'Language';

  static _i6.PageInfo page = _i6.PageInfo(
    name,
    builder: (data) {
      return const _i2.Language();
    },
  );
}

/// generated route for
/// [_i3.NewHome]
class NewHome extends _i6.PageRouteInfo<void> {
  const NewHome({List<_i6.PageRouteInfo>? children})
      : super(
          NewHome.name,
          initialChildren: children,
        );

  static const String name = 'NewHome';

  static _i6.PageInfo page = _i6.PageInfo(
    name,
    builder: (data) {
      return const _i3.NewHome();
    },
  );
}

/// generated route for
/// [_i4.ReportIssue]
class ReportIssue extends _i6.PageRouteInfo<void> {
  const ReportIssue({List<_i6.PageRouteInfo>? children})
      : super(
          ReportIssue.name,
          initialChildren: children,
        );

  static const String name = 'ReportIssue';

  static _i6.PageInfo page = _i6.PageInfo(
    name,
    builder: (data) {
      return const _i4.ReportIssue();
    },
  );
}

/// generated route for
/// [_i5.Setting]
class Setting extends _i6.PageRouteInfo<void> {
  const Setting({List<_i6.PageRouteInfo>? children})
      : super(
          Setting.name,
          initialChildren: children,
        );

  static const String name = 'Setting';

  static _i6.PageInfo page = _i6.PageInfo(
    name,
    builder: (data) {
      return const _i5.Setting();
    },
  );
}
