import 'package:flutter_screenutil/flutter_screenutil.dart';

extension ScreenUtilsSize on ScreenUtil {
  bool isSmallScreen() {
    return screenWidth < 600;
  }
}
