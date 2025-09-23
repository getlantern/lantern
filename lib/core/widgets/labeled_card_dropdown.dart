import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';

class LabeledCardDropdownWithFlag extends StatelessWidget {
  final String titleKey;
  final String countryCode;
  final String countryLabelKey;
  final VoidCallback onChoose;
  final Color? cardColor;

  const LabeledCardDropdownWithFlag({
    super.key,
    required this.titleKey,
    required this.countryCode,
    required this.countryLabelKey,
    required this.onChoose,
    this.cardColor,
  });

  @override
  Widget build(BuildContext context) {
    final finalizeCardColor = cardColor ?? Colors.white;

    return Container(
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
      decoration: BoxDecoration(
        color: finalizeCardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray2, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titleKey.i18n,
            style: AppTestStyles.titleMedium.copyWith(
              color: Colors.black,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 4),
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.gray2,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Country flag and location name
                Row(
                  children: [
                    CountryFlag.fromCountryCode(
                      countryCode,
                      width: 24,
                      height: 16,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      countryLabelKey.i18n,
                      style: AppTestStyles.bodyLarge.copyWith(
                        color: AppColors.black1,
                        height: 1.62,
                      ),
                    ),
                  ],
                ),
                AppTextButton(
                  label: 'choose'.i18n,
                  onPressed: onChoose,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
