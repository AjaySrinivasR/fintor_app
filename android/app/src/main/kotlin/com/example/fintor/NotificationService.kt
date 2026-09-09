package com.example.fintor

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class NotificationService : NotificationListenerService() {
    companion object {
        var notificationListener: ((packageName: String, title: String, text: String) -> Unit)? = null
        val SUPPORTED_PACKAGES = setOf(
            "com.google.android.apps.nbu.paisa.user", // Google Pay
            "com.phonepe.app",                       // PhonePe
            "net.one97.paytm",                        // Paytm
            "com.dreamplug.androidapp"               // CRED
        )
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val packageName = sbn?.packageName ?: return
        if (packageName !in SUPPORTED_PACKAGES) return

        val extras = sbn.notification.extras
        val title = extras.getString(Notification.EXTRA_TITLE) ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""

        if (title.isNotEmpty() && text.isNotEmpty()) {
            notificationListener?.invoke(packageName, title, text)
        }
    }
}