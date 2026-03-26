import 'package:intl/intl.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/plan_data.dart';
import 'package:lantern/core/utils/currency_utils.dart';
import 'package:lantern/core/models/user.dart';

final _ddmmyyFormatter = DateFormat('dd/MM/yy');
final _mmddyyFormatter = DateFormat('MM/dd/yy');

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

extension IsoDateFormatter on UserDataModel {
  String toDate() {
    try {
      if (userLevel == 'expired') {
        if (lastExpiredOn <= 0) {
          return "N/A";
        }
        final expirationDate = DateTime.fromMillisecondsSinceEpoch(
          lastExpiredOn * 1000,
          isUtc: true,
        ).toLocal();
        final formattedDate = _formatDate(expirationDate);
        return "$formattedDate  ${'expired'.i18n}";
      }

      final autoRenew = subscriptionData.autoRenew;
      final endAt = subscriptionData.endAt;
      // Validate expiration exists
      if (expiration <= 0) {
        return "N/A";
      }
      if (autoRenew && endAt != 0) {
        // Active subscription case
        if (endAt <= 0) {
          return "N/A";
        }
        final dateTime = DateTime.fromMillisecondsSinceEpoch(
          endAt * 1000,
          isUtc: true,
        ).toLocal();

        return _formatDate(dateTime);
      }
      // Non-subscription plan case
      final expirationDate = DateTime.fromMillisecondsSinceEpoch(
        expiration * 1000,
        isUtc: true,
      ).toLocal();
      final formattedDate = _formatDate(expirationDate);
      if (expirationDate.isBefore(DateTime.now())) {
        return "$formattedDate  ${'expired'.i18n}";
      }
      return formattedDate;
    } catch (e) {
      return "N/A";
    }
  }

  String _formatDate(DateTime dateTime) {
    final mm = dateTime.month.toString().padLeft(2, '0');
    final dd = dateTime.day.toString().padLeft(2, '0');
    final yy = (dateTime.year % 100).toString().padLeft(2, '0');
    return "$mm/$dd/$yy";
  }
}
