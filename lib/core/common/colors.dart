import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';

Color transparent = Colors.transparent;

Color blue1 = HexColor('#EFFDFF');
Color blue3 = HexColor('#00BCD4');
Color blue4 = HexColor('#007A7C');
Color blue5 = HexColor('#006163');

Color yellow3 = HexColor('#FFE600');
Color yellow4 = HexColor('#FFC107');
Color yellow5 = HexColor('#D6A000');
Color yellow6 = HexColor('#957000');

Color pink1 = HexColor('#FFF4F8');
Color pink3 = HexColor('#FF4081');
Color pink4 = HexColor('#DB0A5B');
Color pink5 = HexColor('#C20850');

// Grey scale
Color white = HexColor('#FFFFFF');
Color grey1 = HexColor('#F9F9F9');
Color grey2 = HexColor('#F5F5F5');
Color grey3 = HexColor('#EBEBEB');
Color grey4 = HexColor('#BFBFBF');
Color grey5 = HexColor('#707070');
Color scrimGrey = HexColor('#C4C4C4');
Color black = HexColor('#000000');

Color red = HexColor('#D5001F');

Color videoControlsGrey = black.withOpacity(0.1);

// Avatars
Color getAvatarColor(double hue, {bool inverted = false}) {
  return HSLColor.fromAHSL(1, hue, 1, 0.3).toColor();
}

// @echo
Color getReplicaMimeBgColor(String mime) {
  final hue = sha1Hue(mime);
  return HSLColor.fromAHSL(0.6, hue, 0.3, 0.2).toColor();
}

// gradient color pairs map
List<List<Color>> gradientColors = [
  [HexColor('#007A7C'), HexColor('#00237C')],
  [HexColor('#9174CE'), HexColor('#749CCE')],
  [HexColor('#5DADEC'), HexColor('#5DD2EC')],
  [HexColor('#007A7C'), HexColor('#0A7C00')],
  [HexColor('#007A7C'), HexColor('#00237C')],
];

// default "unknown" filetype colors
List<Color> unknownColors = [HexColor('#68028C'), HexColor('#C91153')];

// create consistent random gradient mappings from strings
// this method mirrors the generator in desktop
List<Color> stringToGradientColors(String string) {
  // for "unknown" mapping
  if (string.isEmpty) return unknownColors;

  // ensure string is always at least 5 chars long (space is smallest single char code 32)
  string = string + '     ';
  var arr = string.split('').sublist(0, 5).map((r) {
    return r.codeUnitAt(0);
  }).toList();
  final largest = arr.reduce(max);
  final index = arr.indexWhere(((n) => n == largest));
  return gradientColors[index];
}

BoxDecoration getReplicaExtensionBgDecoration(String extension) {
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: const Alignment(0.8, 1),
      colors: stringToGradientColors(extension.replaceAll('.', '')),
      tileMode: TileMode.mirror,
    ),
  );
}

BoxDecoration getReplicaHashAnimatedBgDecoration(
  String hash,
  double animatedValue,
) {
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment(-1 + animatedValue, -1),
      end: Alignment(animatedValue, 0),
      colors: stringToGradientColors(hash),
      tileMode: TileMode.mirror,
    ),
  );
}

BoxDecoration getReplicaHashBgDecoration(String hash) {
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: const Alignment(0.8, 1),
      colors: stringToGradientColors(hash),
      tileMode: TileMode.mirror,
    ),
  );
}

final maxSha1Hash = BigInt.from(2).pow(160);
final numHues = BigInt.from(360);

double sha1Hue(String value) {
  var bytes = utf8.encode(value);
  var digest = sha1.convert(bytes);
  return (BigInt.parse(digest.toString(), radix: 16) * numHues ~/ maxSha1Hash)
      .toDouble();
}

// Indicator
Color indicatorGreen = HexColor('#00A83E');
Color indicatorRed = HexColor('#D5001F');

// Overlay
Color overlayBlack = HexColor('#000000CB');

// Checkbox color helper
Color getCheckboxFillColor(Color activeColor, Set<MaterialState> states) {
  const interactiveStates = <MaterialState>{
    MaterialState.pressed,
    MaterialState.hovered,
    MaterialState.focused,
  };
  return states.any(interactiveStates.contains) ? white : activeColor;
}

// Button colors
Color getBgColor(bool secondary, bool disabled, bool tertiary) {
  if (secondary) return white;
  if (tertiary) return black;
  if (disabled) return grey5;
  return pink4;
}

Color getBorderColor(bool disabled, bool tertiary) {
  if (tertiary) return black;
  if (disabled) return grey5;
  return pink4;
}

/*
******************
REUSABLE COLORS
******************
*/

Color outboundBgColor = blue4;
Color outboundMsgColor = white;

Color inboundMsgColor = black;
Color inboundBgColor = grey2;

Color snippetShadowColor = black.withOpacity(0.18);

Color selectedTabColor = white;
Color unselectedTabColor = grey1;

Color selectedTabIconColor = black;
Color unselectedTabIconColor = grey5;

Color borderColor = grey3;

Color onSwitchColor = blue3;
Color offSwitchColor = grey5;
Color usedDataBarColor = blue4;
