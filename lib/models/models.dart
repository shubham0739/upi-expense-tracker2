import 'package:flutter/material.dart';

/// A single expense record, e.g. "₹200 paid to the restaurant via PhonePe".
class Expense {
  int? id;
  double amount;
  String payee;
  String category;
  String note;
  String paidVia;
  DateTime date;
  int? smsId; // Android SMS message id, used to avoid double-logging
  DateTime createdAt;

  Expense({
    this.id,
    required this.amount,
    this.payee = '',
    this.category = 'Other',
    this.note = '',
    this.paidVia = '',
    required this.date,
    this.smsId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? date;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'amount': amount,
        'payee': payee,
        'category': category,
        'note': note,
        'paid_via': paidVia,
        'date': date.toIso8601String(),
        'sms_id': smsId,
        'created_at': createdAt.toIso8601String(),
      };

  factory Expense.fromMap(Map<String, dynamic> m) => Expense(
        id: m['id'] as int?,
        amount: (m['amount'] as num).toDouble(),
        payee: (m['payee'] ?? '') as String,
        category: (m['category'] ?? 'Other') as String,
        note: (m['note'] ?? '') as String,
        paidVia: (m['paid_via'] ?? '') as String,
        date: DateTime.parse(m['date'] as String),
        smsId: m['sms_id'] as int?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

/// A spending limit. `category` is empty for an overall budget.
class Budget {
  int? id;
  String category;
  double amount;
  String period; // 'monthly' | 'weekly'

  Budget({
    this.id,
    this.category = '',
    required this.amount,
    this.period = 'monthly',
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'category': category,
        'amount': amount,
        'period': period,
      };

  factory Budget.fromMap(Map<String, dynamic> m) => Budget(
        id: m['id'] as int?,
        category: (m['category'] ?? '') as String,
        amount: (m['amount'] as num).toDouble(),
        period: (m['period'] ?? 'monthly') as String,
      );
}

/// A recurring payment (rent, Netflix, loan EMI) that should be logged
/// when it comes due.
class Reminder {
  int? id;
  String title;
  String category;
  double amount;
  String frequency; // 'monthly' | 'weekly' | 'yearly'
  int dayOf; // monthly: day 1-31 · weekly: ISO weekday 1-7 · yearly: month*100+day
  String? lastFired; // ISO date of the last time it was logged
  bool enabled;

  Reminder({
    this.id,
    required this.title,
    this.category = 'Other',
    this.amount = 0,
    this.frequency = 'monthly',
    this.dayOf = 1,
    this.lastFired,
    this.enabled = true,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'category': category,
        'amount': amount,
        'frequency': frequency,
        'day_of': dayOf,
        'last_fired': lastFired,
        'enabled': enabled ? 1 : 0,
      };

  factory Reminder.fromMap(Map<String, dynamic> m) => Reminder(
        id: m['id'] as int?,
        title: (m['title'] ?? '') as String,
        category: (m['category'] ?? 'Other') as String,
        amount: (m['amount'] as num).toDouble(),
        frequency: (m['frequency'] ?? 'monthly') as String,
        dayOf: (m['day_of'] as num?)?.toInt() ?? 1,
        lastFired: m['last_fired'] as String?,
        enabled: (m['enabled'] as num? ?? 1) != 0,
      );
}

/// A UPI payment app the user can launch from the home screen.
class UpiApp {
  final String id;
  final String name;
  final String packageName; // Android package, empty when unknown
  final String? fallbackUri; // deep link used when the package is missing
  final IconData icon;
  final Color color;

  const UpiApp({
    required this.id,
    required this.name,
    required this.packageName,
    this.fallbackUri,
    required this.icon,
    required this.color,
  });
}

/// A UPI payment confirmation SMS, parsed into structured fields.
class SmsCandidate {
  final int smsId;
  final String sender;
  final String body;
  final DateTime date;
  final double? amount;
  final String? payee;

  const SmsCandidate({
    required this.smsId,
    required this.sender,
    required this.body,
    required this.date,
    this.amount,
    this.payee,
  });

  factory SmsCandidate.fromMap(Map<dynamic, dynamic> m) {
    final body = (m['body'] ?? '').toString();
    return SmsCandidate(
      smsId: (m['id'] as num?)?.toInt() ?? 0,
      sender: (m['address'] ?? '').toString(),
      body: body,
      date: DateTime.fromMillisecondsSinceEpoch((m['date'] as num?)?.toInt() ?? 0),
      amount: extractAmount(body),
      payee: extractPayee(body),
    );
  }
}

/// What the app knows when the user returns from a UPI app:
/// any payment SMSes detected since launch, and which app was launched.
class ReturnPromptData {
  final List<SmsCandidate> candidates;
  final String? appId;

  const ReturnPromptData({required this.candidates, this.appId});
}

/// Extracts the first rupee amount from a UPI SMS body, e.g.
/// "Rs.200.00", "INR 1,250", "₹45.50". Returns null when none is found.
double? extractAmount(String text) {
  final m = RegExp(
    r'(?:rs\.?|inr|₹)\s*([0-9][0-9,]*(\.[0-9]{1,2})?)',
    caseSensitive: false,
  ).firstMatch(text);
  if (m == null) return null;
  final v = m.group(1)!.replaceAll(',', '');
  return double.tryParse(v);
}

/// Best-effort extraction of the payee from a UPI SMS body.
String? extractPayee(String text) {
  final vpa = RegExp(
    r'vpa[:\s]+([A-Za-z0-9._-]+@[A-Za-z0-9._-]+)',
    caseSensitive: false,
  ).firstMatch(text);
  if (vpa != null) return vpa.group(1)!.trim();

  final paidTo = RegExp(
    r'paid (?:to|2)\s+([A-Za-z0-9@._ -]+?)(?=\s+(?:via|on|at|from|ref|\.|,)|$)',
    caseSensitive: false,
  ).firstMatch(text);
  if (paidTo != null) {
    final v = paidTo.group(1)!.trim();
    if (v.length >= 2) return v;
  }

  final to = RegExp(
    r'\bto\s+([A-Za-z0-9@._ -]{2,40}?)(?=\s+(?:via|on|at|from|ref|\.|,)|$)',
    caseSensitive: false,
  ).firstMatch(text);
  if (to != null) return to.group(1)!.trim();
  return null;
}

int _clampInt(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

int _daysInMonth(int year, int month) {
  if (month == 2) {
    final leap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
    return leap ? 29 : 28;
  }
  if (month == 4 || month == 6 || month == 9 || month == 11) return 30;
  return 31;
}

/// The next date on which [r] is due, on or after [from] (time-of-day is
/// normalized to [from]'s). Returns null for unknown frequencies.
DateTime? nextDueDate(Reminder r, DateTime from) {
  final today = DateTime(from.year, from.month, from.day);
  switch (r.frequency) {
    case 'monthly':
      var d = DateTime(
          from.year, from.month, _clampInt(r.dayOf, 1, _daysInMonth(from.year, from.month)));
      if (d.isBefore(today)) {
        final next = DateTime(from.year, from.month + 1, 1);
        d = DateTime(next.year, next.month,
            _clampInt(r.dayOf, 1, _daysInMonth(next.year, next.month)));
      }
      return d;
    case 'weekly':
      final diff = (r.dayOf - today.weekday) % 7;
      var d = today.add(Duration(days: diff));
      if (d.isBefore(today)) d = d.add(const Duration(days: 7));
      return d;
    case 'yearly':
      final month = _clampInt(r.dayOf ~/ 100, 1, 12);
      final day = _clampInt(r.dayOf % 100, 1, _daysInMonth(from.year, month));
      var d = DateTime(from.year, month, day);
      if (d.isBefore(today)) {
        d = DateTime(from.year + 1, month,
            _clampInt(r.dayOf % 100, 1, _daysInMonth(from.year + 1, month)));
      }
      return d;
    default:
      return null;
  }
}
