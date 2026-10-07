package com.example.fintor

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

class MainActivity: FlutterActivity() {
    private val SMS_CHANNEL = "com.fintor.app/sms"
    private val NOTIF_CHANNEL = "com.fintor.app/notifications"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. SMS Channel
        val smsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL)
        smsChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "setSmsSyncEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    val prefs = getSharedPreferences("fintor_prefs", Context.MODE_PRIVATE)
                    prefs.edit().putBoolean("sms_sync_enabled", enabled).apply()
                    result.success(true)
                }
                "getOfflinePendingSms" -> {
                    try {
                        val prefs = getSharedPreferences(SmsReceiver.PREF_NAME, Context.MODE_PRIVATE)
                        val rawJson = prefs.getString(SmsReceiver.KEY_PENDING, "[]") ?: "[]"
                        val array = JSONArray(rawJson)
                        val list = mutableListOf<Map<String, String>>()

                        for (i in 0 until array.length()) {
                            val item = array.getJSONObject(i)
                            list.add(mapOf(
                                "sender" to item.optString("sender", ""),
                                "body" to item.optString("body", "")
                            ))
                        }

                        // Clear queue once retrieved
                        prefs.edit().remove(SmsReceiver.KEY_PENDING).apply()
                        result.success(list)
                    } catch (e: Exception) {
                        result.success(emptyList<Map<String, String>>())
                    }
                }
                else -> result.notImplemented()
            }
        }

        SmsReceiver.listener = { sender, messageBody ->
            runOnUiThread {
                smsChannel.invokeMethod("onSmsReceived", mapOf(
                    "sender" to sender,
                    "body" to messageBody
                ))
            }
        }

        // 2. Notification Listener Channel
        val notifChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIF_CHANNEL)
        notifChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "openNotificationSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.localizedMessage, null)
                    }
                }
                "isNotificationListenerEnabled" -> {
                    try {
                        val cn = ComponentName(context, NotificationService::class.java)
                        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
                        val enabled = flat != null && flat.contains(cn.flattenToString())
                        result.success(enabled)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "getOfflinePendingNotifications" -> {
                    try {
                        val prefs = getSharedPreferences(NotificationService.PREF_NAME, Context.MODE_PRIVATE)
                        val rawJson = prefs.getString(NotificationService.KEY_PENDING, "[]") ?: "[]"
                        val array = JSONArray(rawJson)
                        val list = mutableListOf<Map<String, String>>()

                        for (i in 0 until array.length()) {
                            val item = array.getJSONObject(i)
                            list.add(mapOf(
                                "package" to item.optString("package", ""),
                                "title" to item.optString("title", ""),
                                "text" to item.optString("text", "")
                            ))
                        }

                        prefs.edit().remove(NotificationService.KEY_PENDING).apply()
                        result.success(list)
                    } catch (e: Exception) {
                        result.success(emptyList<Map<String, String>>())
                    }
                }
                else -> result.notImplemented()
            }
        }

        NotificationService.notificationListener = { pkg, title, text ->
            runOnUiThread {
                notifChannel.invokeMethod("onNotificationReceived", mapOf(
                    "package" to pkg,
                    "title" to title,
                    "text" to text
                ))
            }
        }
    }
}
