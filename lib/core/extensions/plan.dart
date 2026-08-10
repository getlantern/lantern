import 'package:intl/intl.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/plan_data.dart';
import 'package:lantern/core/models/user.dart';
import 'package:lantern/core/utils/currency_utils.dart';

final _ddmmyyFormatter = DateFormat('dd/MM/yy');
final _mmddyyFormatter = DateFormat('MM/dd/yy');

extension PlanExtension on Plan {
  String get formattedYearlyPrice => _formatPriceMap(price);

  String get formattedMonthlyPrice => _formatPriceMap(expectedMonthlyPrice);

  /// The original (pre-discount) yearly price, taken directly from the
  /// backend's `originalPrice` (no calculation). Shown as the strikethrough
  /// price next to the discounted price when an affiliate code is applied.
  /// Empty when the backend didn't supply an original price.
  String get formatOriginalPrice => _formatPriceMap(originalPrice);

  /// The amount deducted by the affiliate discount: original − discounted
  /// yearly price, both taken directly from the backend (no percentage math).
  /// Shown as the "Promo Code" deduction at checkout. Empty when the backend
  /// didn't supply an original price.
  String get formatDiscountAmount {
    final original = originalPrice;
    if (original == null || original.isEmpty) return '';
    final deducted = _amountOf(original) - _amountOf(price);
    return CurrencyUtils.formatCurrency(deducted, price.keys.first);
  }

  /// Formats the first `<currency>: amount` entry of [prices] as currency;
  /// returns '' when [prices] is null or empty.
  String _formatPriceMap(Map<String, dynamic>? prices) {
    if (prices == null || prices.isEmpty) return '';
    return CurrencyUtils.formatCurrency(_amountOf(prices), prices.keys.first);
  }

  double _amountOf(Map<String, dynamic> prices) =>
      double.parse(prices.values.first.toString());

  String getDurationText() {
    final durationMap = {'1y': 'year', '2y': 'two year', '1m': 'month'};

    final key = id.split('-').first;
    return durationMap[key] ?? '';
  }
}

extension IsoDateFormatter on UserDataModel {
  String toDate() {
    try {
      if (isExpired) {
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

  /// Formatted account expiration when it extends past the subscription's
  /// endAt (e.g. stacked or support-granted time). Null when there is no
  /// extra time to show.
  String? get extendedExpirationDate {
    if (isExpired) return null;
    final endAt = subscriptionData.endAt;
    if (!subscriptionData.autoRenew || endAt <= 0) return null;
    if (expiration <= endAt) return null;
    final expirationDate = DateTime.fromMillisecondsSinceEpoch(
      expiration * 1000,
      isUtc: true,
    ).toLocal();
    return _formatDate(expirationDate);
  }

  String _formatDate(DateTime dateTime) {
    final mm = dateTime.month.toString().padLeft(2, '0');
    final dd = dateTime.day.toString().padLeft(2, '0');
    final yy = (dateTime.year % 100).toString().padLeft(2, '0');
    return "$mm/$dd/$yy";
  }
}
