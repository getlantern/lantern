import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';

import '../common/common.dart';

class AppPinField extends StatelessWidget {
  final Function(String)? onCompleted;
  final Function(String)? onChanged;
  final TextEditingController? controller;

  const AppPinField({
    super.key,
    this.onCompleted,
    this.onChanged,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.gray3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          AppImage(path: AppImagePaths.number),
          SizedBox(width: defaultSize),
          Expanded(
            child: Pinput(
              length: 6,
              showCursor: true,
              onCompleted: onCompleted,
              onChanged: onChanged,
              controller: controller,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              cursor: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 2,
                    height: 20,
                    color: AppColors.gray4,
                  ),
                ],
              ),
              preFilledWidget: Container(
                width: 15,
                height: 1,
                color: AppColors.gray4,
              ),
              defaultPinTheme: PinTheme(
                width: 20,
                height: 45,
                textStyle: Theme.of(context).textTheme.titleMedium,
                decoration: BoxDecoration(),
              ),
              focusedPinTheme: PinTheme(
                width: 20,
                height: 45,
                textStyle: Theme.of(context).textTheme.titleMedium,
                decoration: BoxDecoration(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
