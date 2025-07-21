import 'package:flutter/material.dart';

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
