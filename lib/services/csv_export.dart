import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../utils/format.dart';

/// Exports all expenses to a CSV file in Downloads and opens the Android
/// share sheet. Returns the file path (null when sharing failed).
class CsvExporter {
  static String _escape(String s) {
    final v = s.replaceAll('"', '""');
    return (v.contains(',') || v.contains('"') || v.contains('\n'))
        ? '"$v"'
        : v;
  }

  static Future<String?> exportAndShare(
    List<Expense> expenses, {
    String symbol = '₹',
  }) async {
    final buffer = StringBuffer('Date,Amount,Payee,Category,Note,Paid Via\n');
    final sorted = [...expenses]..sort((a, b) => a.date.compareTo(b.date));
    for (final e in sorted) {
      buffer.writeln([
        formatDateYmd(e.date),
        formatMoneyPlain(e.amount),
        _escape(e.payee),
        _escape(e.category),
        _escape(e.note),
        _escape(e.paidVia),
      ].join(','));
    }

    final dir = await getDownloadsDirectory();
    final base = dir?.path ?? Directory.systemTemp.path;
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    final path = '$base/upi_expenses_$stamp.csv';
    final file = File(path);
    await file.writeAsString(buffer.toString());

    try {
      await SharePlus.instance.share(ShareParams(
        files: [XFile(path)],
        subject: 'UPI Expense Tracker export',
        text: 'Expenses exported from UPI Expense Tracker ($symbol)',
      ));
      return path;
    } catch (_) {
      return null;
    }
  }
}
