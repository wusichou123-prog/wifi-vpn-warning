package com.wusic.wifi_warning

import android.app.Activity
import android.app.NotificationManager
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class WarningActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        val message = intent.getStringExtra("message") ?: "检测到高风险网络状态"

        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(64, 64, 64, 64)
            setBackgroundColor(Color.rgb(176, 0, 32))
        }
        content.addView(TextView(this).apply {
            text = "网络安全警告"
            textSize = 34f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
        })
        content.addView(TextView(this).apply {
            text = message
            textSize = 20f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            setPadding(0, 42, 0, 42)
        })
        content.addView(Button(this).apply {
            text = "我已确认"
            textSize = 18f
            setOnClickListener { acknowledge() }
        })
        setContentView(content)
        AlertSoundPlayer.start(this)
    }

    @Suppress("DEPRECATION")
    override fun onBackPressed() {
        // Deliberately ignored: the warning must be acknowledged.
    }

    private fun acknowledge() {
        AlertSoundPlayer.stop(this)
        getSystemService(NotificationManager::class.java)
            .cancel(MonitorNotifications.ALERT_ID)
        startService(
            Intent(this, MonitorService::class.java)
                .setAction(MonitorService.ACTION_ACK)
        )
        finish()
    }
}
