import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database.dart';
import '../models/models.dart';
import '../services/csv_export.dart';
import '../services/sms_service.dart';
import '../utils/categories.dart';
import '../utils/format.dart';

/// Central app state: settings, expenses, budgets, reminders, categories,
/// and the "return from UPI app" detection flow.
class AppState extends ChangeNotifier {
  final AppDatabase _db = AppDatabase();

  // ---- Settings ---------------------------------------------------------
  bool smsAutoDetect = true;
  String currencySymbol = '₹';
  ThemeMode themeMode = ThemeMode.system;

  // ---- Data -------------------------------------------------------------
  List<Expense> expenses = [];
  List<Budget> budgets = [];
  List<Reminder> reminders = [];
  List<Reminder> dueReminders = [];
  List<CategoryInfo> categories = [...defaultCategories];

  /// Set to non-null when the user returns from a UPI app; the root shell
  /// listens to this and opens the "what did you pay for?" sheet.
  final ValueNotifier<ReturnPromptData?> returnPrompt = ValueNotifier(null);

  bool get hasOverallBudget => budgets.any((b) => b.category.isEmpty);

  // ---- Lifecycle --------------------------------------------------------
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    smsAutoDetect = prefs.getBool('sms_auto_detect') ?? true;
    currencySymbol = prefs.getString('currency_symbol') ?? '₹';
    final themeIndex = prefs.getInt('theme_mode') ?? 0;
    final safeIndex = themeIndex < 0
        ? 0
        : (themeIndex >= ThemeMode.values.length
            ? ThemeMode.values.length - 1
            : themeIndex);
    themeMode = ThemeMode.values[safeIndex];
    await _loadCustomCategories();
    await _reload();
  }

  Future<void> _loadCustomCategories() async {
    final db = await _db.database;
    final rows = await db.query('custom_categories');
    final custom = rows
        .map((r) => CategoryInfo(
              (r['name'] ?? '') as String,
              Icons.category,
              Color((r['color'] as num?)?.toInt() ?? 0xFF607D8B),
            ))
        .where((c) => c.name.isNotEmpty)
        .toList();
    categories = [...defaultCategories, ...custom];
  }

  Future<void> _reload() async {
    final db = await _db.database;
    final eRows = await db.query('expenses', orderBy: 'date DESC');
    expenses = eRows.map(Expense.fromMap).toList();
    final bRows = await db.query('budgets');
    budgets = bRows.map(Budget.fromMap).toList();
    final rRows = await db.query('reminders');
    reminders = rRows.map(Reminder.fromMap).toList();
    _computeDue();
    notifyListeners();
  }

  // ---- Expenses ---------------------------------------------------------
  /// Inserts a new expense or updates an existing one (when [e.id] is set).
  /// Expenses logged from an SMS are skipped when that SMS was already used.
  Future<void> saveExpense(Expense e) async {
    final db = await _db.database;
    if (e.id != null) {
      await db.update('expenses', e.toMap(), where: 'id = ?', whereArgs: [e.id]);
    } else {
      if (e.smsId != null) {
        final existing =
            await db.query('expenses', where: 'sms_id = ?', whereArgs: [e.smsId]);
        if (existing.isNotEmpty) {
          await _reload();
          return;
        }
      }
      await db.insert('expenses', e.toMap());
    }
    await _reload();
  }

  Future<void> deleteExpense(int id) async {
    final db = await _db.database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
    await _reload();
  }

  // ---- Budgets ----------------------------------------------------------
  Future<void> saveBudget(Budget b) async {
    final db = await _db.database;
    if (b.id != null) {
      await db.update('budgets', b.toMap(), where: 'id = ?', whereArgs: [b.id]);
    } else {
      await db.insert('budgets', b.toMap());
    }
    await _reload();
  }

  Future<void> deleteBudget(int id) async {
    final db = await _db.database;
    await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
    await _reload();
  }

  // ---- Reminders --------------------------------------------------------
  Future<void> saveReminder(Reminder r) async {
    final db = await _db.database;
    if (r.id != null) {
      await db.update('reminders', r.toMap(), where: 'id = ?', whereArgs: [r.id]);
    } else {
      await db.insert('reminders', r.toMap());
    }
    await _reload();
  }

  Future<void> deleteReminder(int id) async {
    final db = await _db.database;
    await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
    await _reload();
  }

  /// Logs a due reminder as a paid expense and marks it fired.
  Future<void> logReminder(Reminder r) async {
    final now = DateTime.now();
    await saveExpense(Expense(
      amount: r.amount,
      payee: r.title,
      category: r.category,
      paidVia: 'Recurring',
      note: '',
      date: now,
    ));
    final db = await _db.database;
    final today = DateTime(now.year, now.month, now.day);
    await db.update('reminders', {'last_fired': today.toIso8601String()},
        where: 'id = ?', whereArgs: [r.id]);
    await _reload();
  }

  void _computeDue() {
    final today = DateTime.now();
    dueReminders = reminders.where((r) => r.enabled && _isDue(r, today)).toList();
  }

  static bool _isDue(Reminder r, DateTime today) {
    final due = nextDueDate(r, today);
    if (due == null) return false;
    if (due.isAfter(DateTime(today.year, today.month, today.day))) return false;
    if (r.lastFired != null) {
      final lf = DateTime.parse(r.lastFired!);
      final lfDay = DateTime(lf.year, lf.month, lf.day);
      if (due == lfDay) return false;
    }
    return true;
  }

  // ---- Custom categories --------------------------------------------------
  Future<void> addCustomCategory(String name, Color color) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (categories.any((c) => c.name == trimmed)) return;
    final db = await _db.database;
    // ignore: deprecated_member_use
    await db.insert('custom_categories', {'name': trimmed, 'color': color.value});
    categories = [...categories, CategoryInfo(trimmed, Icons.category, color)];
    notifyListeners();
  }

  // ---- Category lookups ----------------------------------------------------
  CategoryInfo categoryInfo(String name) =>
      categories.firstWhere((c) => c.name == name,
          orElse: () => defaultCategories.last);

  Color categoryColor(String name) => categoryInfo(name).color;
  IconData categoryIcon(String name) => categoryInfo(name).icon;

  // ---- Aggregations ---------------------------------------------------------
  double spentThisMonth([DateTime? now]) {
    final key = monthKey(now ?? DateTime.now());
    return expenses
        .where((e) => monthKey(e.date) == key)
        .fold(0.0, (s, e) => s + e.amount);
  }

  double spentThisWeek([DateTime? now]) {
    final n = now ?? DateTime.now();
    final start = DateTime(n.year, n.month, n.day)
        .subtract(Duration(days: n.weekday - 1));
    return expenses
        .where((e) =>
            !e.date.isBefore(start) && !e.date.isAfter(DateTime(n.year, n.month, n.day)))
        .fold(0.0, (s, e) => s + e.amount);
  }

  List<Expense> expensesForMonth(DateTime m) {
    final key = monthKey(m);
    return expenses.where((e) => monthKey(e.date) == key).toList();
  }

  /// category name -> total spent, for the given month.
  Map<String, double> spentByCategory(DateTime m) {
    final out = <String, double>{};
    for (final e in expensesForMonth(m)) {
      out[e.category] = (out[e.category] ?? 0) + e.amount;
    }
    return out;
  }

  /// day key -> total, for the given month.
  Map<String, double> spentByDay(DateTime m) {
    final out = <String, double>{};
    for (final e in expensesForMonth(m)) {
      final k = dayKey(e.date);
      out[k] = (out[k] ?? 0) + e.amount;
    }
    return out;
  }

  /// month key -> total, for the last [count] months including the current one.
  Map<String, double> monthlyTotals(int count) {
    final out = <String, double>{};
    final now = DateTime.now();
    for (var i = count - 1; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      out[monthKey(m)] = 0;
    }
    for (final e in expenses) {
      final k = monthKey(e.date);
      if (out.containsKey(k)) out[k] = (out[k] ?? 0) + e.amount;
    }
    return out;
  }

  /// payee -> total, sorted descending, for the given month.
  List<MapEntry<String, double>> topPayees(DateTime m) {
    final map = <String, double>{};
    for (final e in expensesForMonth(m)) {
      final key = e.payee.isEmpty ? e.category : e.payee;
      map[key] = (map[key] ?? 0) + e.amount;
    }
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  double spentForBudget(Budget b, [DateTime? now]) {
    final n = now ?? DateTime.now();
    Iterable<Expense> inPeriod;
    if (b.period == 'weekly') {
      final start = DateTime(n.year, n.month, n.day)
          .subtract(Duration(days: n.weekday - 1));
      final end = DateTime(n.year, n.month, n.day);
      inPeriod = expenses.where(
          (e) => !e.date.isBefore(start) && !e.date.isAfter(end));
    } else {
      final key = monthKey(n);
      inPeriod = expenses.where((e) => monthKey(e.date) == key);
    }
    if (b.category.isNotEmpty) {
      inPeriod = inPeriod.where((e) => e.category == b.category);
    }
    return inPeriod.fold(0.0, (s, e) => s + e.amount);
  }

  // ---- Return-from-UPI flow ---------------------------------------------------
  /// Called when the app resumes. If a UPI app was launched recently and the
  /// user has come back, gathers detected SMSes (when enabled) and emits a
  /// [ReturnPromptData] so the UI can ask "what did you pay for?".
  Future<void> handleReturnToApp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getBool('return_pending') ?? false;
      if (!pending) return;
      final since = prefs.getInt('last_upi_launch') ?? 0;
      final appId = prefs.getString('last_upi_app');
      await prefs.remove('return_pending');
      final elapsed = DateTime.now().millisecondsSinceEpoch - since;
      if (elapsed > 45 * 60 * 1000) return; // stale launch
      List<SmsCandidate> candidates = const [];
      if (smsAutoDetect) {
        candidates = await SmsService.instance.recentUpiSms(since);
      }
      returnPrompt.value = ReturnPromptData(candidates: candidates, appId: appId);
    } catch (_) {
      // Never crash on a resume event.
    }
  }

  // ---- Settings ------------------------------------------------------------
  Future<void> setSmsAutoDetect(bool value) async {
    smsAutoDetect = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sms_auto_detect', value);
    notifyListeners();
  }

  Future<void> setCurrencySymbol(String value) async {
    final v = value.trim();
    if (v.isEmpty) return;
    currencySymbol = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency_symbol', v);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
    notifyListeners();
  }

  Future<void> clearAllData() async {
    final db = await _db.database;
    await db.delete('expenses');
    await db.delete('budgets');
    await db.delete('reminders');
    await db.delete('custom_categories');
    categories = [...defaultCategories];
    await _reload();
  }

  Future<String?> exportCsv() =>
      CsvExporter.exportAndShare(expenses, symbol: currencySymbol);

  @override
  void dispose() {
    returnPrompt.dispose();
    super.dispose();
  }
}
