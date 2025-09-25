import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';

import '../common/app_colors.dart';

class Flag extends StatelessWidget {
  final String countryCode;
  final Size? size;

  const Flag({
    super.key,
    required this.countryCode,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.gray8, width: 0.5),
        borderRadius: BorderRadius.circular(5),
      ),
      child: CountryFlag.fromCountryCode(
        countryCode,
        height: size?.height ?? 20,
        width: size?.width ?? 30,
        shape: RoundedRectangle(5.0),
      ),
    );
  }
}
