import 'package:flutter/material.dart';

//// A round button
class RoundButton extends StatelessWidget {
  final Widget icon;
  final double diameter;
  final double padding;
  final Color backgroundColor;
  final Color splashColor;
  final void Function() onPressed;

  RoundButton({
    required this.icon,
    this.diameter = 56,
    this.padding = 2,
    required this.backgroundColor,
    this.splashColor = Colors.white,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    // return ClipOval(
    //   child: SizedBox(
    //     width: diameter,
    //     height: diameter,
    //     child: Material(
    //       color: backgroundColor, // button color
    //       child: CInkWell(
    //         onTap: onPressed, // button pressed
    //         child: Column(
    //           mainAxisAlignment: MainAxisAlignment.center,
    //           children: <Widget>[
    //             icon,
    //           ],
    //         ),
    //       ),
    //     ),
    //   ),
    // );
    return SizedBox(
      width: diameter,
      height: diameter,
      child: TextButton(
        onPressed: onPressed,
        style: ButtonStyle(
          padding:
              MaterialStateProperty.all(EdgeInsetsDirectional.all(padding)),
          backgroundColor: MaterialStateProperty.all(backgroundColor),
          shape: MaterialStateProperty.all(const CircleBorder()),
        ),
        child: icon,
      ),
    );
  }
}
