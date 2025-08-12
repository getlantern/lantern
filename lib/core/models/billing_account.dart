import 'package:lantern/core/common/app_eum.dart';

class BillingAccount {
  final CloudProvider provider;

  final String id;
  final String text;
  const BillingAccount(
      {required this.provider, required this.id, required this.text});
}
