import 'package:flutter/material.dart';
import 'package:lantern/core/common/text.dart';


/*
******************
BASE STYLES
https://www.figma.com/file/Jz424KUVkFFc2NsxuYaZKL/Lantern-Component-Library?node-id=2%3A115
******************
*/

CTextStyle tsDisplay(color) => CTextStyle(
      fontSize: 48,
      lineHeight: 48,
      color: color,
    );

CTextStyle tsDisplayBlack = tsDisplay(Colors.black);

CTextStyle tsHeading1 =
    CTextStyle(fontSize: 24, minFontSize: 18, lineHeight: 39);

CTextStyle tsHeading3 = CTextStyle(
  fontSize: 20,
  minFontSize: 16,
  lineHeight: 23.44,
  fontWeight: FontWeight.w500,
);

CTextStyle tsSubtitle1 = CTextStyle(
  fontSize: 16,
  // minFontSize: 12, // removing this solves the IntrinsicWidth vs LayoutBuilder issues we are experiencing, look into custom/text.dart for more
  lineHeight: 26,
);

CTextStyle tsSubtitle1Short = tsSubtitle1.copiedWith(lineHeight: 21);

CTextStyle tsSubtitle2 = CTextStyle(
  fontSize: 14,
  // minFontSize: 12, // removing this solves the IntrinsicWidth vs LayoutBuilder issues we are experiencing, look into custom/text.dart for more
  lineHeight: 23,
  fontWeight: FontWeight.w500,
);

CTextStyle tsSubtitle3 = CTextStyle(
  fontFamily: 'Roboto',
  fontSize: 14,
  lineHeight: 23,
);

CTextStyle tsSubtitle4 = CTextStyle(
  fontFamily: 'Roboto',
  fontSize: 14,
  lineHeight: 23,
  fontWeight: FontWeight.w500,
);

CTextStyle tsBody1 = CTextStyle(
  fontSize: 14,
  lineHeight: 23,
);

CTextStyle tsBody1Short = CTextStyle(fontSize: 14, lineHeight: 18);

CTextStyle tsBody1Color(color) => tsBody1.copiedWith(color: color);

CTextStyle tsBody2 = CTextStyle(fontSize: 12, lineHeight: 19);

CTextStyle tsBody2Short = CTextStyle(fontSize: 12, lineHeight: 14);

CTextStyle tsBody3 = CTextStyle(fontSize: 16, lineHeight: 24);

CTextStyle tsTextField = CTextStyle(fontSize: 16, lineHeight: 18.75);

CTextStyle tsFloatingLabel =
    CTextStyle(fontSize: 12, lineHeight: 12, fontWeight: FontWeight.w400);

CTextStyle tsButton = CTextStyle(
  fontSize: 14,
  lineHeight: 14,
  fontWeight: FontWeight.w500,
);

CTextStyle tsOverline = CTextStyle(fontSize: 10, lineHeight: 16);

CTextStyle tsOverlineShort =
    tsOverline.copiedWith(lineHeight: tsOverline.fontSize);

CTextStyle tsCodeDisplay1 = CTextStyle(
  fontFamily: 'RobotoMono',
  fontSize: 20,
  lineHeight: 32,
);

/*
******************
BUTTON VARIATIONS
******************
*/

// CTextStyle tsButtonGrey = tsButton.copiedWith(color: grey5);
//
// CTextStyle tsButtonPink = tsButton.copiedWith(color: pink4);
//
// CTextStyle tsButtonWhite = tsButton.copiedWith(color: white);
//
// CTextStyle tsButtonBlue = tsButton.copiedWith(color: blue4);



/*
*********
EMOTICONS
*********
*/

