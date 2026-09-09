package com.example.fintor

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import org.json.JSONArray
import org.json.JSONObject

class SmsReceiver : BroadcastReceiver() {
    companion object {
        var listener: ((sender: String, messageBody: String) -> Unit)? = null
        const val PREF_NAME = "fintor_offline_sms"
        const val KEY_PENDING = "pending_sms_queue"
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent?.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        // 1. Verify if user has enabled SMS sync
        val appPrefs = context.getSharedPreferences("fintor_prefs", Context.MODE_PRIVATE)
        val isEnabled = appPrefs.getBoolean("sms_sync_enabled", false)
        if (!isEnabled) return

        // 2. Extract messages
        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        for (sms in messages) {
            val sender = sms.originatingAddress ?: ""
            val body = sms.messageBody ?: ""

            // 3. Drop OTPs & verification noise
            val isOtp = body.contains("OTP", ignoreCase = true) || 
                        body.contains("verification code", ignoreCase = true) ||
                        body.contains("secret", ignoreCase = true)
            
            if (!isOtp) {
                if (listener != null) {
                    // App is open in foreground
                    listener?.invoke(sender, body)
                } else {
                    // App is fully closed / killed: write straight to native disk
                    saveOfflineSms(context, sender, body)
                }
            }
        }
    }

    private fun saveOfflineSms(context: Context, sender: String, body: String) {
        val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        val currentJson = prefs.getString(KEY_PENDING, "[]") ?: "[]"
        val array = JSONArray(currentJson)

        val obj = JSONObject().apply {
            put("sender", sender)
            put("body", body)
            put("timestamp", System.currentTimeMillis())
        }
        array.put(obj)
        prefs.edit().putString(KEY_PENDING, array.toString()).apply()
    }
}