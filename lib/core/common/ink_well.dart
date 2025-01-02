import 'package:flutter/material.dart';
import 'package:lantern/core/common/colors.dart';

class CInkWell extends StatelessWidget {
  final Widget child;
  final Function onTap;
  final RoundedRectangleBorder? customBorder;
  final bool disableSplash;
  final Color? overrideColor;

  const CInkWell({
    required this.child,
    required this.onTap,
    this.customBorder,
    this.disableSplash = false,
    this.overrideColor,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: transparent,
      child: InkWell(
        focusColor: disableSplash ? transparent : overrideColor ?? grey4,
        splashColor: disableSplash ? transparent : overrideColor ?? grey4,
        highlightColor: disableSplash ? transparent : overrideColor ?? grey4,
        borderRadius: const BorderRadius.all(
          Radius.circular(8.0),
        ),
        onTap: () => onTap(),
        customBorder: customBorder,
        child: child,
      ),
    );
  }
}
