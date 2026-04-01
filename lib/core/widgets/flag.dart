import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';

class Flag extends StatelessWidget {
  final String countryCode;
  final Size size;

  const Flag({
    super.key,
    required this.countryCode,
    this.size = const Size(25, 18),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: size,
      child: CountryFlag.fromCountryCode(
        countryCode,
        theme: ImageTheme(
          shape: RoundedRectangle(4),
          height: size.height,
          width: size.width,
        ),
      ),
    );
  }
}
