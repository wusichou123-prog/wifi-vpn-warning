package com.wusic.wifi_warning

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.os.Build
import androidx.core.app.NotificationCompat

object MonitorNotifications {
    const val MONITOR_ID = 1001
    const val ALERT_ID = 2001
    const val MONITOR_CHANNEL = "network_monitor"
    const val ALERT_CHANNEL = "network_alerts"

    fun createChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
        val monitor = NotificationChannel(
            MONITOR_CHANNEL,
            "持续网络监控",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "显示网络和 VPN 监控正在运行"
            setShowBadge(false)
        }
        val alerts = NotificationChannel(
            ALERT_CHANNEL,
            "网络安全警告",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Wi-Fi 或时间规则命中时的强提醒"
            enableVibration(true)
            setShowBadge(true)
            setSound(
                android.provider.Settings.System.DEFAULT_ALARM_ALERT_URI,
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
        }
        manager.createNotificationChannel(monitor)
        manager.createNotificationChannel(alerts)
    }

    fun foreground(context: Context, text: String): Notification {
        val open = PendingIntent.getActivity(
            context,
            1,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(context, MONITOR_CHANNEL)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentTitle("网络 VPN 警告")
            .setContentText(text)
            .setContentIntent(open)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    fun alert(context: Context, message: String, overlayEnabled: Boolean): Notification {
        val intent = Intent(context, WarningActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            .putExtra("message", message)
        val pending = PendingIntent.getActivity(
            context,
            2,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(context, ALERT_CHANNEL)
            .setSmallIcon(android.R.drawable.stat_sys_warning)
            .setContentTitle("网络安全警告")
            .setContentText(message)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setContentIntent(pending)
            .setAutoCancel(false)
            .setOngoing(true)
            .setFullScreenIntent(pending, overlayEnabled)
            .build()
    }
}
