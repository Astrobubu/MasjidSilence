package com.example.mosquesilence_dnd

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MosquesilenceDndPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
  private lateinit var channel: MethodChannel
  private lateinit var appContext: Context

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    appContext = binding.applicationContext
    channel = MethodChannel(binding.binaryMessenger, "mosquesilence/dnd")
    channel.setMethodCallHandler(this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    val nm = appContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    when (call.method) {
      "isPolicyAccessGranted" -> result.success(nm.isNotificationPolicyAccessGranted)
      "gotoPolicySettings" -> {
        val i = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        appContext.startActivity(i)
        result.success(null) // void
      }
      "setInterruptionFilter" -> {
        val mode = (call.argument<String>("mode") ?: "all").lowercase()
        val filter = when (mode) {
          "none" -> NotificationManager.INTERRUPTION_FILTER_NONE
          "priority" -> NotificationManager.INTERRUPTION_FILTER_PRIORITY
          "alarms" -> NotificationManager.INTERRUPTION_FILTER_ALARMS
          else -> NotificationManager.INTERRUPTION_FILTER_ALL
        }
        nm.setInterruptionFilter(filter)
        result.success(nm.currentInterruptionFilter)

      }
      "getInterruptionFilter" -> {
        // Return current Android interruption filter as int
        result.success(nm.currentInterruptionFilter)
      }
      else -> result.notImplemented()
    }
  }
}
