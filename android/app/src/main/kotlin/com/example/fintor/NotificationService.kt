package com.example.fintor

import android.app.Notification
import android.content.Context
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject

class NotificationService : NotificationListenerService() {
    companion object {
        const val PREF_NAME = "fintor_notif_prefs"
        const val KEY_PENDING = "pending_notifications"

        var notificationListener: ((packageName: String, title: String, text: String) -> Unit)? = null

        val SUPPORTED_PACKAGES = setOf(
            "com.google.android.apps.nbu.paisa.user", // Google Pay
            "com.phonepe.app",                       // PhonePe
            "net.one97.paytm",                        // Paytm
            "com.dreamplug.androidapp",               // CRED
            "in.org.npci.upiapp",                    // BHIM UPI
            "com.whatsapp",                          // WhatsApp Pay
            "in.amazon.mShop.android.shopping",      // Amazon Pay
            "com.sbi.lotusintouch",                  // YONO SBI
            "com.msf.kbank.mobile",                  // Kotak 811
            "com.icicibank.imobile",                 // iMobile
            "com.axis.mobile",                       // Axis Mobile
            "com.snapwork.hdfc"                      // HDFC Mobile
        )
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val packageName = sbn?.packageName ?: return
        val notification = sbn.notification ?: return
        val extras = notification.extras ?: return

        val title = extras.getString(Notification.EXTRA_TITLE)
            ?: extras.getCharSequence(Notification.EXTRA_TITLE_BIG)?.toString()
            ?: ""

        val text = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
            ?: extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
            ?: extras.getCharSequence(Notification.EXTRA_INFO_TEXT)?.toString()
            ?: extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString()
            ?: ""

        if (title.isEmpty() && text.isEmpty()) return

        val combined = "$title $text".lowercase()
        val isSupportedPackage = packageName in SUPPORTED_PACKAGES
        val hasFinancialKeywords = combined.contains("paid") ||
                combined.contains("debited") ||
                combined.contains("credited") ||
                combined.contains("received") ||
                combined.contains("sent") ||
                combined.contains("payment") ||
                combined.contains("spent") ||
                combined.contains("₹") ||
                combined.contains("inr") ||
                combined.contains("rs.") ||
                combined.contains("rs ")

        if (!isSupportedPackage && !hasFinancialKeywords) return

        val listener = notificationListener
        if (listener != null) {
            listener.invoke(packageName, title, text)
        } else {
            savePendingNotification(packageName, title, text)
        }
    }

    private fun savePendingNotification(packageName: String, title: String, text: String) {
        try {
            val prefs = getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
            val rawJson = prefs.getString(KEY_PENDING, "[]") ?: "[]"
            val array = JSONArray(rawJson)

            val item = JSONObject().apply {
                put("package", packageName)
                put("title", title)
                put("text", text)
            }
            array.put(item)
            prefs.edit().putString(KEY_PENDING, array.toString()).apply()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}