import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';

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
    return CountryFlag.fromCountryCode(
      countryCode,
      height: size?.height ?? 20,
      width: size?.width ?? 30,
      shape: RoundedRectangle(5.0),
    );
  }
}
