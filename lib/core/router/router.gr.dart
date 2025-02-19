// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:auto_route/auto_route.dart' as _i4;
import 'package:lantern/features/home/home.dart' as _i1;
import 'package:lantern/features/home/new_home.dart' as _i2;
import 'package:lantern/features/setting/setting.dart' as _i3;

/// generated route for
/// [_i1.HomePage]
class Home extends _i4.PageRouteInfo<void> {
  const Home({List<_i4.PageRouteInfo>? children})
      : super(
          Home.name,
          initialChildren: children,
        );

  static const String name = 'Home';

  static _i4.PageInfo page = _i4.PageInfo(
    name,
    builder: (data) {
      return const _i1.HomePage();
    },
  );
}

/// generated route for
/// [_i2.NewHome]
class NewHome extends _i4.PageRouteInfo<void> {
  const NewHome({List<_i4.PageRouteInfo>? children})
      : super(
          NewHome.name,
          initialChildren: children,
        );

  static const String name = 'NewHome';

  static _i4.PageInfo page = _i4.PageInfo(
    name,
    builder: (data) {
      return const _i2.NewHome();
    },
  );
}

/// generated route for
/// [_i3.Setting]
class Setting extends _i4.PageRouteInfo<void> {
  const Setting({List<_i4.PageRouteInfo>? children})
      : super(
          Setting.name,
          initialChildren: children,
        );

  static const String name = 'Setting';

  static _i4.PageInfo page = _i4.PageInfo(
    name,
    builder: (data) {
      return const _i3.Setting();
    },
  );
}
