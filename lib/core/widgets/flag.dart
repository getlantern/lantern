import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';

import '../common/app_colors.dart';

class Flag extends StatelessWidget {
  final String countryCode;
  final Size size;

  const Flag({
    super.key,
    required this.countryCode,
    this.size = const  Size(25, 18)
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.gray3, width: .5),
      ),
      child: SizedBox.fromSize(
        size: size,
        child: CountryFlag.fromCountryCode(
          countryCode,
          theme: ImageTheme(
            shape: RoundedRectangle(3),
            height: size.height,
            width: size.width,
          ),
        ),
      ),
    );
  }
}
