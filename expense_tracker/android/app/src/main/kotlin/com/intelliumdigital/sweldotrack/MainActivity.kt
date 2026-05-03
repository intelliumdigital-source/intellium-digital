package com.intelliumdigital.sweldotrack

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import android.os.Build
import android.provider.Settings
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val appInfoChannel = "sweldotrack/app_info"
        private const val notificationChannel =
            "sweldotrack/smart_expense_detection/notifications"
        private const val controlChannel =
            "sweldotrack/smart_expense_detection/control"
        private const val notificationAction =
            "com.intelliumdigital.sweldotrack.SMART_EXPENSE_NOTIFICATION"
    }

    private var notificationReceiver: BroadcastReceiver? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            appInfoChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAppVersion" -> {
                    runCatching {
                        val packageInfo = packageManager.getPackageInfo(packageName, 0)
                        val buildNumber = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            packageInfo.longVersionCode.toString()
                        } else {
                            @Suppress("DEPRECATION")
                            packageInfo.versionCode.toString()
                        }

                        result.success(
                            hashMapOf(
                                "versionName" to packageInfo.versionName.orEmpty(),
                                "buildNumber" to buildNumber,
                            )
                        )
                    }.onFailure { error ->
                        result.error(
                            "app_info_unavailable",
                            error.message,
                            null
                        )
                    }
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            controlChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isNotificationListenerEnabled" -> {
                    result.success(isNotificationListenerEnabled())
                }

                "openNotificationListenerSettings" -> {
                    runCatching {
                        startActivity(
                            Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                        )
                    }.onSuccess {
                        result.success(true)
                    }.onFailure { error ->
                        result.error(
                            "notification_settings_unavailable",
                            error.message,
                            null
                        )
                    }
                }

                "syncSmartExpenseDetectionConfig" -> {
                    val detectionEnabled =
                        call.argument<Boolean>("enabled") ?: false
                    val monitoredApps =
                        call.argument<List<*>>("monitoredApps")
                            ?.mapNotNull { it as? String }
                            ?: emptyList()

                    SmartExpenseDetectionConfigStore.update(
                        applicationContext,
                        detectionEnabled = detectionEnabled,
                        monitoredApps = monitoredApps,
                    )
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            notificationChannel
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    unregisterNotificationReceiver()

                    notificationReceiver = object : BroadcastReceiver() {
                        override fun onReceive(context: Context?, intent: Intent?) {
                            if (intent?.action != notificationAction) return

                            events.success(
                                hashMapOf(
                                    "packageName" to intent.getStringExtra("packageName").orEmpty(),
                                    "title" to intent.getStringExtra("title").orEmpty(),
                                    "text" to intent.getStringExtra("text").orEmpty(),
                                    "subText" to intent.getStringExtra("subText").orEmpty(),
                                    "notificationId" to intent.getIntExtra("notificationId", 0),
                                    "postTime" to intent.getLongExtra("postTime", 0L),
                                )
                            )
                        }
                    }

                    val filter = IntentFilter(notificationAction)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        registerReceiver(
                            notificationReceiver,
                            filter,
                            Context.RECEIVER_NOT_EXPORTED
                        )
                    } else {
                        @Suppress("DEPRECATION")
                        registerReceiver(notificationReceiver, filter)
                    }
                }

                override fun onCancel(arguments: Any?) {
                    unregisterNotificationReceiver()
                }
            }
        )
    }

    override fun onDestroy() {
        unregisterNotificationReceiver()
        super.onDestroy()
    }

    private fun unregisterNotificationReceiver() {
        val receiver = notificationReceiver ?: return
        runCatching {
            unregisterReceiver(receiver)
        }
        notificationReceiver = null
    }

    private fun isNotificationListenerEnabled(): Boolean {
        val enabledListeners = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners"
        ).orEmpty()
        if (enabledListeners.isBlank()) {
            return false
        }

        return enabledListeners.split(':').any { componentName ->
            ComponentName.unflattenFromString(componentName)?.packageName == packageName
        }
    }
}
