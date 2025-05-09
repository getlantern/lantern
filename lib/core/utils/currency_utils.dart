import 'package:intl/intl.dart';

class CurrencyUtils {
  static String getCurrencySymbol(String currencyCode) {
    final format = NumberFormat.simpleCurrency(name: currencyCode);
    return format.currencySymbol;
  }

  static String formatCurrency(double amount, String currencyCode) {
    final format =
        NumberFormat.simpleCurrency(name: currencyCode.toUpperCase());
    return format.format((amount / 100));
  }
}
