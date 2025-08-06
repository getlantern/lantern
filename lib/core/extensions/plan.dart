import 'package:intl/intl.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/plan_data.dart';
import 'package:lantern/core/utils/currency_utils.dart';
import 'package:lantern/lantern/protos/protos/auth.pb.dart';

final _ddmmyyFormatter = DateFormat('dd/MM/yy');

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

  String getDurationText() {
    final durationMap = {
      '1y': 'year',
      '2y': 'two year',
      '1m': 'month',
    };

    final key = id.split('-').first;
    return durationMap[key] ?? '';
  }
}

extension IsoDateFormatter on UserResponse_UserData {
  String toDate() {
    try {
      final autoRenew = subscriptionData.autoRenew;
      final endAt = subscriptionData.endAt;
      if (PlatformUtils.isIOS) {
        final dateTime = DateTime.parse(endAt).toLocal();
        final mm = dateTime.month.toString().padLeft(2, '0');
        final dd = dateTime.day.toString().padLeft(2, '0');
        final yy = (dateTime.year % 100).toString().padLeft(2, '0');
        return "$mm/$dd/$yy";
      }
      if (endAt == "" || autoRenew == false) {
        // User is on non subscription plan
        final newDate =
            DateTime.fromMillisecondsSinceEpoch(expiration.toInt() * 1000);
        return _ddmmyyFormatter.format(newDate);
      }
      final dateTime = DateTime.parse(endAt).toLocal();
      final mm = dateTime.month.toString().padLeft(2, '0');
      final dd = dateTime.day.toString().padLeft(2, '0');
      final yy = (dateTime.year % 100).toString().padLeft(2, '0');
      return "$mm/$dd/$yy";
    } catch (_) {
      return "N/A"; // return original string if parsing fails
    }
  }
}
