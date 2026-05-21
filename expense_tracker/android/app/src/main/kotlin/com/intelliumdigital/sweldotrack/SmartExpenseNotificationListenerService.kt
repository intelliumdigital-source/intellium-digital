package com.intelliumdigital.sweldotrack

import android.app.Notification
import android.content.Context
import android.content.Intent
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

internal object SmartExpenseDetectionConfigStore {
    private const val preferencesName = "sweldotrack_smart_expense_detection"
    private const val detectionEnabledKey = "detection_enabled"
    private const val allowedPackagesKey = "allowed_packages"

    // Keep this aligned with Flutter's smartExpenseSupportedApps mapping so
    // native allowlisting and Dart-side parsing support the same packages.
    private val supportedPackagesByLabel = mapOf(
        "GCash" to setOf("com.globe.gcash.android"),
        "Maya" to setOf("com.paymaya", "com.maya.ph"),
        "Shopee" to setOf("com.shopee.ph"),
        "Lazada" to setOf("com.lazada.android"),
        "Foodpanda" to setOf(
            "com.global.foodpanda.android",
            "com.deliveryhero.foodpanda",
        ),
        "Grab" to setOf("com.grabtaxi.passenger"),
    )

    data class Config(
        val enabled: Boolean,
        val allowedPackages: Set<String>,
    )

    fun update(
        context: Context,
        detectionEnabled: Boolean,
        monitoredApps: List<String>,
    ) {
        val resolvedAllowedPackages = if (!detectionEnabled) {
            emptySet()
        } else {
            monitoredApps
                .asSequence()
                .map { it.trim() }
                .filter { it.isNotEmpty() }
                .flatMap { label -> supportedPackagesByLabel[label].orEmpty().asSequence() }
                .map { it.trim() }
                .filter { it.isNotEmpty() }
                .toSet()
        }

        context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(
                detectionEnabledKey,
                detectionEnabled && resolvedAllowedPackages.isNotEmpty(),
            )
            .apply {
                if (resolvedAllowedPackages.isEmpty()) {
                    remove(allowedPackagesKey)
                } else {
                    putStringSet(allowedPackagesKey, resolvedAllowedPackages)
                }
            }
            .apply()
    }

    fun read(context: Context): Config {
        val preferences =
            context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
        val allowedPackages =
            preferences
                .getStringSet(allowedPackagesKey, emptySet())
                .orEmpty()
                .asSequence()
                .map { it.trim() }
                .filter { it.isNotEmpty() }
                .toSet()
        val enabled =
            preferences.getBoolean(detectionEnabledKey, false) &&
                allowedPackages.isNotEmpty()

        return Config(
            enabled = enabled,
            allowedPackages = allowedPackages,
        )
    }
}

class SmartExpenseNotificationListenerService : NotificationListenerService() {
    companion object {
        private const val notificationAction =
            "com.intelliumdigital.sweldotrack.SMART_EXPENSE_NOTIFICATION"
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val statusBarNotification = sbn ?: return
        val sourcePackageName = statusBarNotification.packageName.orEmpty().trim()
        if (sourcePackageName.isEmpty()) {
            return
        }

        val config = SmartExpenseDetectionConfigStore.read(applicationContext)
        if (!config.enabled || !config.allowedPackages.contains(sourcePackageName)) {
            return
        }

        val extras = statusBarNotification.notification.extras ?: return

        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString().orEmpty()
        val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString().orEmpty()
        if (title.isBlank() && text.isBlank() && subText.isBlank()) {
            return
        }

        val intent = Intent(notificationAction).apply {
            setPackage(applicationContext.packageName)
            putExtra("packageName", sourcePackageName)
            putExtra("title", title)
            putExtra("text", text)
            putExtra("subText", subText)
            putExtra("notificationId", statusBarNotification.id)
            putExtra("postTime", statusBarNotification.postTime)
        }
        sendBroadcast(intent)
    }
}
