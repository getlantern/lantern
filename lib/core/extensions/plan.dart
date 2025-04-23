import 'package:lantern/core/models/plan_data.dart';
import 'package:lantern/core/utils/currency_utils.dart';

extension PlanExtension on Plan {
  String get formattedYearlyPrice {
    return CurrencyUtils.formatCurrency(
        double.parse(price.values.first.toString()), price.keys.first);
  }
  String get formattedMonthlyPrice {
    return CurrencyUtils.formatCurrency(
        double.parse(expectedMonthlyPrice.values.first.toString()),
        expectedMonthlyPrice.keys.first);
  }
}
