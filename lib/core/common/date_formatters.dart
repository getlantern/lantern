import 'package:intl/intl.dart';

class AppDateFormats {
  /// 3:00 AM
  static final DateFormat time = DateFormat('h:mm a');

  /// Thu
  static final DateFormat weekday = DateFormat('EEE');

  /// December 23rd — month name with ordinal day, per the renewal designs.
  /// Ordinal suffixes are an English feature; other locales get their own
  /// month-and-day pattern (e.g. "23 de diciembre") instead of English
  /// suffixes bolted onto a translated month.
  static String monthDayOrdinal(DateTime date) {
    final locale = Intl.getCurrentLocale();
    if (!locale.startsWith('en')) {
      return DateFormat.MMMMd(locale).format(date);
    }
    final day = date.day;
    final suffix = switch (day % 100) {
      11 || 12 || 13 => 'th',
      _ => switch (day % 10) { 1 => 'st', 2 => 'nd', 3 => 'rd', _ => 'th' },
    };
    return '${DateFormat.MMMM().format(date)} $day$suffix';
  }
}
