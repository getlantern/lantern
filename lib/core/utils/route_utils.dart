import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';

Widget slideLeftToRight(BuildContext context, Animation<double> animation,
    Animation<double> secondaryAnimation, Widget child) {
  const begin = Offset(-1.0, 0.0);
  const end = Offset.zero;
  final tween =
      Tween(begin: begin, end: end).chain(CurveTween(curve: Curves.easeInOut));
  return SlideTransition(
    position: animation.drive(tween),
    child: child,
  );
}

Future<void> safePush(BuildContext context, PageRouteInfo route) async {
  try {
    await appRouter.push(route);
  } catch (e) {
    print('Navigation error: $e');
  }
}
