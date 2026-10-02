package com.wusic.wifi_warning

import android.content.Context
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

object AlertSoundPlayer {
    private var ringtone: Ringtone? = null
    private var vibrator: Vibrator? = null

    @Synchronized
    fun start(context: Context) {
        stop(context)
        ringtone = RingtoneManager.getRingtone(
            context,
            RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
        ).also {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                it.audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            }
            it.play()
        }
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE)
                as VibratorManager
            manager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        vibrator?.vibrate(
            VibrationEffect.createWaveform(
                longArrayOf(0, 500, 300, 500, 800),
                0
            )
        )
    }

    @Synchronized
    fun stop(context: Context) {
        ringtone?.stop()
        ringtone = null
        vibrator?.cancel()
        vibrator = null
    }
}
