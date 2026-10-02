import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';

/// The UPI payment apps shown on the home screen. Package names are used to
/// launch the app directly on Android; the fallback deep link is tried when
/// the package cannot be launched.
class UpiLauncher {
  static const List<UpiApp> apps = [
    UpiApp(
      id: 'gpay',
      name: 'Google Pay',
      packageName: 'com.google.android.apps.nbu.paisa.user',
      fallbackUri: 'tez://',
      icon: Icons.g_mobiledata,
      color: Color(0xFF4285F4),
    ),
    UpiApp(
      id: 'phonepe',
      name: 'PhonePe',
      packageName: 'com.phonepe.app',
      fallbackUri: 'phonepe://',
      icon: Icons.wallet,
      color: Color(0xFF5F259F),
    ),
    UpiApp(
      id: 'paytm',
      name: 'Paytm',
      packageName: 'net.one97.paytm',
      fallbackUri: 'paytmmp://',
      icon: Icons.account_balance_wallet,
      color: Color(0xFF002E6E),
    ),
    UpiApp(
      id: 'bhim',
      name: 'BHIM',
      packageName: 'in.org.npci.upiapp',
      fallbackUri: 'upi://',
      icon: Icons.currency_rupee,
      color: Color(0xFF00838F),
    ),
    UpiApp(
      id: 'amazonpay',
      name: 'Amazon Pay',
      packageName: 'in.amazon.mShop.android.shopping',
      fallbackUri: 'amazonpayupi://',
      icon: Icons.shopping_cart_outlined,
      color: Color(0xFFFF9900),
    ),
  ];

  static UpiApp byId(String id) =>
      apps.firstWhere((a) => a.id == id, orElse: () => apps.first);

  /// Launches [app] and remembers that a payment may be in flight so the
  /// app can ask "what did you pay for?" when the user comes back.
  static Future<bool> launch(UpiApp app) async {
    await _markPending(app.id);
    if (app.packageName.isEmpty) {
      final ok = await _openUri(app.fallbackUri!);
      if (!ok) await _clearPending();
      return ok;
    }
    try {
      await AndroidIntent(
        action: 'android.intent.action.MAIN',
        category: 'android.intent.category.LAUNCHER',
        package: app.packageName,
      ).launch();
      return true;
    } catch (_) {
      // Package not installed or not launchable — try the deep link.
      try {
        final ok = await _openUri(app.fallbackUri!);
        if (!ok) await _clearPending();
        return ok;
      } catch (_) {
        await _clearPending();
        return false;
      }
    }
  }

  static Future<void> _markPending(String appId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_upi_app', appId);
    await prefs.setInt('last_upi_launch', DateTime.now().millisecondsSinceEpoch);
    await prefs.setBool('return_pending', true);
  }

  static Future<void> _clearPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('return_pending');
  }

  static Future<bool> _openUri(String uri) async {
    final ok = await launchUrl(Uri.parse(uri), mode: LaunchMode.externalApplication);
    return ok;
  }
}
