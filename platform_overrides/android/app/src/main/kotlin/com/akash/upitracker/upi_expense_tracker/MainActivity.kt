package com.akash.upitracker.upi_expense_tracker

import android.content.ContentResolver
import android.provider.Telephony
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

/**
 * Exposes a "recentUpiSms" method on the platform channel
 * "com.akash.upitracker/sms". It reads the SMS inbox for messages that look
 * like UPI payment confirmations since a given timestamp and returns them as
 * a JSON array. The Dart side (lib/services/sms_service.dart) parses amounts
 * and payees.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "com.akash.upitracker/sms"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "recentUpiSms" -> {
                        val since = (call.argument<Number>("since") ?: 0L).toLong()
                        result.success(queryUpiSms(since))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun queryUpiSms(sinceMillis: Long): String {
        val out = JSONArray()
        try {
            val resolver: ContentResolver = applicationContext.contentResolver
            val projection = arrayOf(
                Telephony.Sms.Inbox._ID,
                Telephony.Sms.Inbox.ADDRESS,
                Telephony.Sms.Inbox.BODY,
                Telephony.Sms.Inbox.DATE
            )
            val cursor = resolver.query(
                Telephony.Sms.Inbox.CONTENT_URI,
                projection,
                Telephony.Sms.Inbox.DATE + " >= ?",
                arrayOf(sinceMillis.toString()),
                Telephony.Sms.Inbox.DATE + " DESC"
            )
            cursor?.use {
                val idCol = it.getColumnIndex(Telephony.Sms.Inbox._ID)
                val addrCol = it.getColumnIndex(Telephony.Sms.Inbox.ADDRESS)
                val bodyCol = it.getColumnIndex(Telephony.Sms.Inbox.BODY)
                val dateCol = it.getColumnIndex(Telephony.Sms.Inbox.DATE)
                while (it.moveToNext() && out.length() < 50) {
                    val body = it.getString(bodyCol) ?: ""
                    val lower = body.lowercase()
                    val looksLikeUpi = lower.contains("upi") ||
                        lower.contains("debited") ||
                        lower.contains("paid to") ||
                        lower.contains("payment")
                    if (!looksLikeUpi) continue
                    val obj = JSONObject()
                    obj.put("id", it.getLong(idCol))
                    obj.put("address", it.getString(addrCol) ?: "")
                    obj.put("body", body)
                    obj.put("date", it.getLong(dateCol))
                    out.put(obj)
                }
            }
        } catch (_: SecurityException) {
            // READ_SMS not granted — return an empty list.
        } catch (_: Exception) {
            // Ignore read errors; the app falls back to manual entry.
        }
        return out.toString()
    }
}
