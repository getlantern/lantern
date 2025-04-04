import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';

@RoutePage(name: 'ConfirmEmail')
class ConfirmEmail extends StatelessWidget {
  const ConfirmEmail({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'confirm_email'.i18n,
      body: Column(
        children: <Widget>[],
      ),
    );
  }
}
