import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';

class LabeledCardInput extends StatelessWidget {
  final String header;
  final String label;
  final Widget? input;
  final String? hint;
  final EdgeInsets cardPadding;
  final Object? prefixIcon;
  final Color? cardColor;
  final double? width;
  final TextEditingController? controller;
  final void Function(String)? onChanged;
  final String? Function(String?)? validator;

  const LabeledCardInput({
    super.key,
    required this.header,
    required this.label,
    this.prefixIcon,
    this.hint,
    this.input,
    this.cardPadding = const EdgeInsets.all(16),
    this.cardColor,
    this.controller,
    this.validator,
    this.onChanged,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final _cardColor = cardColor ?? Colors.white;

    return Container(
      width: width ?? double.infinity,
      padding: cardPadding,
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.gray2,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            header,
            style: AppTestStyles.titleMedium.copyWith(
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          input ??
              AppTextField(
                controller: controller,
                label: label,
                prefixIcon: prefixIcon,
                hintText: '',
                onChanged: onChanged,
                validator: validator,
              ),
          if (hint != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                hint!,
                style: AppTestStyles.labelMedium.copyWith(
                  color: AppColors.lightGray,
                  fontWeight: FontWeight.w500,
                  height: 1.33,
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }
}
