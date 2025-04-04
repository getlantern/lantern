import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_colors.dart';

import '../common/app_text_styles.dart';

class PasswordCriteriaWidget extends StatefulWidget {
  final TextEditingController textEditingController;

  const PasswordCriteriaWidget({
    super.key,
    required this.textEditingController,
  });

  @override
  _PasswordCriteriaWidgetState createState() => _PasswordCriteriaWidgetState();
}

class _PasswordCriteriaWidgetState extends State<PasswordCriteriaWidget> {
  bool has8Characters = false;
  bool hasUppercase = false;
  bool hasLowercase = false;
  bool hasNumber = false;
  bool hasSpecialCharacter = false;
  TextTheme? textTheme;

  @override
  void initState() {
    super.initState();
    widget.textEditingController.addListener(_updateCriteria);
  }

  @override
  void dispose() {
    widget.textEditingController.removeListener(_updateCriteria);
    super.dispose();
  }

  void _updateCriteria() {
    final text = widget.textEditingController.text;
    setState(() {
      has8Characters = text.length >= 8;
      hasUppercase = text.contains(RegExp(r'[A-Z]'));
      hasLowercase = text.contains(RegExp(r'[a-z]'));
      hasNumber = text.contains(RegExp(r'[0-9]'));
      hasSpecialCharacter = text.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  @override
  Widget build(BuildContext context) {
    textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
          color: AppColors.white, borderRadius: BorderRadius.circular(8.0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password must contain at least:',
            style: textTheme!.titleMedium,
          ),
          const SizedBox(height: 14),
          _buildCriteriaRow('8 or more characters', has8Characters),
          _buildCriteriaRow('1 UPPERCASE letter', hasUppercase),
          _buildCriteriaRow('1 lowercase letter', hasLowercase),
          _buildCriteriaRow('1 number', hasNumber),
          _buildCriteriaRow('1 special character', hasSpecialCharacter),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildCriteriaRow(String criteria, bool metCriteria) {
    return Padding(
      padding: const EdgeInsets.only(top: 5, bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            metCriteria ? Icons.check_circle : Icons.radio_button_unchecked,
            color: metCriteria ? AppColors.green6 : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            criteria,
            style: textTheme!.labelMedium!.copyWith(
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
