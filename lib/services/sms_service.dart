import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/models.dart';

/// Bridges to the Android SMS inbox through a platform channel implemented
/// in MainActivity.kt. Only messages that look like UPI payment
/// confirmations are returned, and only from the given time onwards.
class SmsService {
  SmsService._();

  static final SmsService instance = SmsService._();
  static const MethodChannel _channel = MethodChannel('com.akash.upitracker/sms');

  Future<bool> get hasPermission async => Permission.sms.isGranted;

  Future<bool> requestPermission() async {
    if (await Permission.sms.isGranted) return true;
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  Future<List<SmsCandidate>> recentUpiSms(int sinceMillis) async {
    try {
      final raw = await _channel.invokeMethod<String>('recentUpiSms', {
        'since': sinceMillis,
      });
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final out = <SmsCandidate>[];
      for (final e in decoded) {
        if (e is Map) {
          final c = SmsCandidate.fromMap(e);
          if (c.amount != null || c.payee != null) out.add(c);
        }
      }
      return out;
    } catch (_) {
      // SMS permission missing or channel unavailable — the caller falls
      // back to manual entry.
      return [];
    }
  }
}
