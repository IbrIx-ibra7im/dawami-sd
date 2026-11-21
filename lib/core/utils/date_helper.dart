import 'package:intl/intl.dart';

class DateHelper {
  static final DateFormat _arabicDateFormat = DateFormat('EEEE d MMMM y', 'ar');
  static final DateFormat _arabicTimeFormat = DateFormat('hh:mm a', 'ar');
  static final DateFormat _arabicDateTimeFormat = DateFormat('yyyy-MM-dd hh:mm a', 'ar');
  static final DateFormat _isoFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  static final DateFormat _dateOnlyFormat = DateFormat('yyyy-MM-dd');

  static String formatFullDate(DateTime date) {
    try {
      return _arabicDateFormat.format(date);
    } catch (_) {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }

  static String formatTime(DateTime date) {
    try {
      return _arabicTimeFormat.format(date);
    } catch (_) {
      final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
      final period = date.hour >= 12 ? 'م' : 'ص';
      return '${hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} $period';
    }
  }

  static String formatDateTime(DateTime date) {
    try {
      return _arabicDateTimeFormat.format(date);
    } catch (_) {
      return '${formatFullDate(date)} ${formatTime(date)}';
    }
  }

  static String toIso(DateTime date) {
    return _isoFormat.format(date);
  }

  static String toDateOnly(DateTime date) {
    return _dateOnlyFormat.format(date);
  }

  static DateTime parseIso(String iso) {
    try {
      return DateTime.parse(iso);
    } catch (_) {
      return DateTime.now();
    }
  }

  static String formatTimeString(String? isoString, {String placeholder = '-'}) {
    if (isoString == null || isoString.isEmpty) return placeholder;
    return formatTime(parseIso(isoString));
  }
}

