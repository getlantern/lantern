import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';

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
    final results = widget.textEditingController.text.getValidationResults();
    setState(() {
      has8Characters = results['At least 8 characters'] ?? false;
      hasUppercase = results['Contains uppercase letter'] ?? false;
      hasLowercase = results['Contains lowercase letter'] ?? false;
      hasNumber = results['Contains number'] ?? false;
      hasSpecialCharacter = results['Contains special character'] ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: AppColors.gray3,
          width: .5,
        ),
      ),
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
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            criteria,
            style: textTheme!.labelMedium!.copyWith(
              fontSize: 14,
              color: AppColors.gray9,
            ),
          ),
        ],
      ),
    );
  }
}
