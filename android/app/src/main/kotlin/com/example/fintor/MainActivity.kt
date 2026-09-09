package com.example.fintor

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.fintor.app/sms"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        channel.setMethodCallHandler { call, result ->
        when (call.method) {
        "setSmsSyncEnabled" -> {
            val enabled = call.argument<Boolean>("enabled") ?: false
            val prefs = getSharedPreferences("fintor_prefs", Context.MODE_PRIVATE)
            prefs.edit().putBoolean("sms_sync_enabled", enabled).apply()
            result.success(true)
        }
         "getOfflinePendingSms" -> {
                val prefs = getSharedPreferences(SmsReceiver.PREF_NAME, Context.MODE_PRIVATE)
                val rawJson = prefs.getString(SmsReceiver.KEY_PENDING, "[]") ?: "[]"
                val array = JSONArray(rawJson)
                val list = mutableListOf<Map<String, String>>()

                for (i in 0 until array.length()) {
                    val item = array.getJSONObject(i)
                    list.add(mapOf(
                        "sender" to item.getString("sender"),
                        "body" to item.getString("body")
                    ))
                }

                // Clear queue once retrieved
                prefs.edit().remove(SmsReceiver.KEY_PENDING).apply()
                result.success(list)
            } else -> result.notImplemented()
            }
        }

        SmsReceiver.listener = { sender, messageBody ->
            runOnUiThread {
                channel.invokeMethod("onSmsReceived", mapOf(
                    "sender" to sender,
                    "body" to messageBody
                ))
            }
        }
        }
    }

