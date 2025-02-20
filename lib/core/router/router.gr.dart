// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:auto_route/auto_route.dart' as _i5;
import 'package:lantern/features/home/home.dart' as _i1;
import 'package:lantern/features/home/new_home.dart' as _i3;
import 'package:lantern/features/language/language.dart' as _i2;
import 'package:lantern/features/setting/setting.dart' as _i4;

/// generated route for
/// [_i1.HomePage]
class Home extends _i5.PageRouteInfo<void> {
  const Home({List<_i5.PageRouteInfo>? children})
      : super(
          Home.name,
          initialChildren: children,
        );

  static const String name = 'Home';

  static _i5.PageInfo page = _i5.PageInfo(
    name,
    builder: (data) {
      return const _i1.HomePage();
    },
  );
}

/// generated route for
/// [_i2.Language]
class Language extends _i5.PageRouteInfo<void> {
  const Language({List<_i5.PageRouteInfo>? children})
      : super(
          Language.name,
          initialChildren: children,
        );

  static const String name = 'Language';

  static _i5.PageInfo page = _i5.PageInfo(
    name,
    builder: (data) {
      return const _i2.Language();
    },
  );
}

/// generated route for
/// [_i3.NewHome]
class NewHome extends _i5.PageRouteInfo<void> {
  const NewHome({List<_i5.PageRouteInfo>? children})
      : super(
          NewHome.name,
          initialChildren: children,
        );

  static const String name = 'NewHome';

  static _i5.PageInfo page = _i5.PageInfo(
    name,
    builder: (data) {
      return const _i3.NewHome();
    },
  );
}

/// generated route for
/// [_i4.Setting]
class Setting extends _i5.PageRouteInfo<void> {
  const Setting({List<_i5.PageRouteInfo>? children})
      : super(
          Setting.name,
          initialChildren: children,
        );

  static const String name = 'Setting';

  static _i5.PageInfo page = _i5.PageInfo(
    name,
    builder: (data) {
      return const _i4.Setting();
    },
  );
}
