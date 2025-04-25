import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/utils/reseller_formatter.dart';

@RoutePage(name: 'ActivationCode')
class ActivationCode extends StatelessWidget {
  const ActivationCode({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'Enter Activation Code',
      body: Column(
        children: <Widget>[
          SizedBox(height: defaultSize),
          AppTextField(
            hintText: 'XXXXX-XXXXX-XXXXX-XXXXX-XXXXX',
            prefixIcon: AppImagePaths.lock,
            label: 'activation_code'.i18n,
            inputFormatters: [
              ResellerCodeFormatter(),
            ],
            onChanged: (value) {},
          ),
          SizedBox(height: 32),
          PrimaryButton(
            label: 'activate_lantern_pro'.i18n,
            onPressed: () {
              appRouter.popUntilRoot();
            },
          ),
          SizedBox(height: defaultSize),
          DividerSpace(),
          SizedBox(height: defaultSize),
        ],
      ),
    );
  }
}
