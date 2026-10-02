import 'package:intl/intl.dart';

/// '2026-10' — used to group expenses by month.
String monthKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

/// '2026-10-02' — used to group expenses by day.
String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// '₹1,234.56' with the configured currency symbol.
String formatMoney(double v, {String symbol = '₹'}) =>
    NumberFormat.currency(locale: 'en_IN', symbol: symbol).format(v);

/// '1234.56' — plain number used in CSV exports.
String formatMoneyPlain(double v) => v.toStringAsFixed(2);

/// '2 Oct 2026, 9:53 AM'
String formatDate(DateTime d) => DateFormat('d MMM yyyy, h:mm a').format(d);

/// '2026-10-02 09:53'
String formatDateYmd(DateTime d) => DateFormat('yyyy-MM-dd HH:mm').format(d);

/// 'October 2026'
String monthLabel(DateTime d) => DateFormat('MMMM yyyy').format(d);

/// 'Oct'
String shortMonth(DateTime d) => DateFormat('MMM').format(d);

/// 'Thu'
String shortDay(DateTime d) => DateFormat('EEE').format(d);

/// Full weekday name for ISO weekday 1 (Monday) .. 7 (Sunday).
String weekdayName(int weekday) =>
    DateFormat('EEEE').format(DateTime(2024, 1, 1 + (weekday - 1)));
